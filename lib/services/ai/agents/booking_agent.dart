import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../ai_types.dart';
import '../specialist_agent.dart';
import '../tool_executor.dart';
import '../tool_registry.dart';
import '../../progress/progress_models.dart';
import '../../progress/progress_event.dart';
import '../../progress/progress_manager.dart';

class BookingAgent implements SpecialistAgent {
  final GenerativeModel _model;
  final ToolExecutor _executor;
  final ProgressManager? _progressManager;

  BookingAgent(this._model, {ToolExecutor? executor, ProgressManager? progressManager}) 
      : _executor = executor ?? ToolExecutor(),
        _progressManager = progressManager;

  @override
  AgentCapability get capability => AgentCapability.booking;

  @override
  Future<AgentResult> execute(AgentTask task, ExecutionState state) async {
    final startTime = DateTime.now();

    final bool isSearch = task.objective.toLowerCase().contains('search') || 
                          task.objective.toLowerCase().contains('find') ||
                          state.originalRequest.toLowerCase().contains('search') ||
                          state.originalRequest.toLowerCase().contains('find');
    
    final progressStage = isSearch ? ProgressStage.searchingHostels : ProgressStage.processingBookings;
    final progressMessage = isSearch ? 'Searching hostels in Islamabad...' : 'Retrieving booking information...';

    _progressManager?.emit(ProgressEvent(
      taskId: task.taskId,
      stage: progressStage,
      status: ProgressStatus.started,
      title: isSearch ? 'Hostel Database' : 'Booking Processor',
      message: progressMessage,
      agentName: 'BookingAgent',
      timestamp: DateTime.now(),
    ));
    
    // Dynamic tool selection for Bookings & Hostels category
    final tools = ToolRegistry.getRegisteredTools().where((t) => t.category == 'Bookings' || t.category == 'Hostels').toList();
    final toolDefsString = tools.map((t) => '- ${t.name}: ${t.description}. Params: ${json.encode(t.parameterSchema)}').join('\n');

    final prompt = '''
You are the HODS Booking Specialist Agent.
Your job is to select the correct hostel search or booking tool, define its arguments, and write reasoning for the selection.

Task Objective: "${task.objective}"
User Request: "${state.originalRequest}"
User Role: ${state.role.name.toUpperCase()}
Working Memory: ${json.encode(state.workingMemory.toMap())}

HODS Booking & Hostel Tools Available:
$toolDefsString

Please select the most appropriate tool to run. You must choose from the available tools.
If no tool is required or all booking/hostel data is already gathered, set "executeTool" to false.

Format your output strictly as a JSON object:
{
  "executeTool": bool,
  "toolName": "string",
  "arguments": {},
  "reasoning": "string"
}
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '{}';
      var cleanText = text;
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll('```json', '').replaceAll('```', '').trim();
      }

      final parsed = json.decode(cleanText) as Map<String, dynamic>;

      if (parsed['executeTool'] == true) {
        final String toolName = parsed['toolName'] ?? '';
        final Map<String, dynamic> arguments = Map<String, dynamic>.from(parsed['arguments'] ?? {});
        final String reasoning = parsed['reasoning'] ?? '';

        final toolCall = ToolCall(
          toolName: toolName,
          arguments: arguments,
          confidence: 0.95,
          reasoning: reasoning,
        );

        // Update message to indicate checking room availability if appropriate
        if (toolName.contains('Booking') || toolName.contains('room')) {
          _progressManager?.emit(ProgressEvent(
            taskId: task.taskId,
            stage: progressStage,
            status: ProgressStatus.running,
            title: isSearch ? 'Hostel Database' : 'Booking Processor',
            message: 'Checking room availability...',
            agentName: 'BookingAgent',
            timestamp: DateTime.now(),
          ));
        }

        final toolResult = await _executor.execute(
          toolName,
          arguments,
          task.requiredInputs['userId']?.toString() ?? 'system_user',
          state.role,
        );

        // Record the step in ExecutionState
        state.steps.add(PlanningStep(
          toolCall: toolCall,
          toolResult: toolResult,
          plannerReasoning: reasoning,
          observation: toolResult.success ? 'Executed booking tool successfully.' : toolResult.error,
        ));
        state.toolExecutionHistory.add(toolResult);

        // Update Working Memory with any results
        if (toolResult.success && toolResult.data.isNotEmpty) {
          final mutable = Map<String, dynamic>.from(state.workingMemory.facts);
          mutable.addAll(toolResult.data);
          state.workingMemory.facts = mutable;
        }

        _progressManager?.emit(ProgressEvent(
          taskId: task.taskId,
          stage: progressStage,
          status: ProgressStatus.completed,
          title: isSearch ? 'Hostel Database' : 'Booking Processor',
          message: isSearch ? 'Found matching hostels.' : 'Retrieved booking details.',
          agentName: 'BookingAgent',
          timestamp: DateTime.now(),
        ));

        return AgentResult(
          taskId: task.taskId,
          agentName: 'BookingAgent',
          success: toolResult.success,
          confidence: 0.95,
          outputs: toolResult.data,
          observations: [reasoning, 'Executed tool $toolName. Success: ${toolResult.success}'],
          executionTime: DateTime.now().difference(startTime),
        );
      } else {
        _progressManager?.emit(ProgressEvent(
          taskId: task.taskId,
          stage: progressStage,
          status: ProgressStatus.completed,
          title: isSearch ? 'Hostel Database' : 'Booking Processor',
          message: 'No further action required.',
          agentName: 'BookingAgent',
          timestamp: DateTime.now(),
        ));

        return AgentResult(
          taskId: task.taskId,
          agentName: 'BookingAgent',
          success: true,
          confidence: 1.0,
          outputs: {},
          observations: [parsed['reasoning'] ?? 'No booking action needed.'],
          executionTime: DateTime.now().difference(startTime),
        );
      }
    } catch (e) {
      _progressManager?.emit(ProgressEvent(
        taskId: task.taskId,
        stage: progressStage,
        status: ProgressStatus.failed,
        severity: ProgressSeverity.error,
        title: isSearch ? 'Hostel Database Failed' : 'Booking Processor Failed',
        message: e.toString(),
        agentName: 'BookingAgent',
        timestamp: DateTime.now(),
      ));

      return AgentResult(
        taskId: task.taskId,
        agentName: 'BookingAgent',
        success: false,
        confidence: 0.0,
        outputs: {},
        observations: ['Booking execution failed: ${e.toString()}'],
        executionTime: DateTime.now().difference(startTime),
      );
    }
  }
}

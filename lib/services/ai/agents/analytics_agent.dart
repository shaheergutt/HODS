import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../ai_types.dart';
import '../specialist_agent.dart';
import '../tool_executor.dart';
import '../tool_registry.dart';
import '../../progress/progress_models.dart';
import '../../progress/progress_event.dart';
import '../../progress/progress_manager.dart';

class AnalyticsAgent implements SpecialistAgent {
  final GenerativeModel _model;
  final ToolExecutor _executor;
  final ProgressManager? _progressManager;

  AnalyticsAgent(this._model, {ToolExecutor? executor, ProgressManager? progressManager}) 
      : _executor = executor ?? ToolExecutor(),
        _progressManager = progressManager;

  @override
  AgentCapability get capability => AgentCapability.analytics;

  @override
  Future<AgentResult> execute(AgentTask task, ExecutionState state) async {
    final startTime = DateTime.now();

    _progressManager?.emit(ProgressEvent(
      taskId: task.taskId,
      stage: ProgressStage.runningAnalytics,
      status: ProgressStatus.started,
      title: 'Analytics Engine',
      message: 'Running analytics check...',
      agentName: 'AnalyticsAgent',
      timestamp: DateTime.now(),
    ));

    final tools = ToolRegistry.getRegisteredTools().where((t) => t.category == 'Analytics').toList();
    final toolDefsString = tools.map((t) => '- ${t.name}: ${t.description}. Params: ${json.encode(t.parameterSchema)}').join('\n');

    final prompt = '''
You are the HODS Analytics Specialist Agent.
Your job is to select the correct HODS business analytics tool, define its arguments, and write reasoning for the selection.

Task Objective: "${task.objective}"
User Request: "${state.originalRequest}"
User Role: ${state.role.name.toUpperCase()}
Working Memory: ${json.encode(state.workingMemory.toMap())}

HODS Analytics Tools Available:
$toolDefsString

Please select the most appropriate tool to run. You must choose from the available tools.
If no tool is required, set "executeTool" to false.

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
          observation: toolResult.success ? 'Executed analytics tool successfully.' : toolResult.error,
        ));
        state.toolExecutionHistory.add(toolResult);

        // Update Working Memory with any results
        if (toolResult.success && toolResult.data.isNotEmpty) {
          state.workingMemory.facts.addAll(toolResult.data);
        }

        _progressManager?.emit(ProgressEvent(
          taskId: task.taskId,
          stage: ProgressStage.runningAnalytics,
          status: ProgressStatus.completed,
          title: 'Analytics Engine',
          message: 'Analytics records loaded.',
          agentName: 'AnalyticsAgent',
          timestamp: DateTime.now(),
        ));

        return AgentResult(
          taskId: task.taskId,
          agentName: 'AnalyticsAgent',
          success: toolResult.success,
          confidence: 0.95,
          outputs: toolResult.data,
          observations: [reasoning, 'Executed tool $toolName. Success: ${toolResult.success}'],
          executionTime: DateTime.now().difference(startTime),
        );
      } else {
        _progressManager?.emit(ProgressEvent(
          taskId: task.taskId,
          stage: ProgressStage.runningAnalytics,
          status: ProgressStatus.completed,
          title: 'Analytics Engine',
          message: 'No further action required.',
          agentName: 'AnalyticsAgent',
          timestamp: DateTime.now(),
        ));

        return AgentResult(
          taskId: task.taskId,
          agentName: 'AnalyticsAgent',
          success: true,
          confidence: 1.0,
          outputs: {},
          observations: [parsed['reasoning'] ?? 'No analytics action needed.'],
          executionTime: DateTime.now().difference(startTime),
        );
      }
    } catch (e) {
      _progressManager?.emit(ProgressEvent(
        taskId: task.taskId,
        stage: ProgressStage.runningAnalytics,
        status: ProgressStatus.failed,
        severity: ProgressSeverity.error,
        title: 'Analytics Engine Failed',
        message: e.toString(),
        agentName: 'AnalyticsAgent',
        timestamp: DateTime.now(),
      ));

      return AgentResult(
        taskId: task.taskId,
        agentName: 'AnalyticsAgent',
        success: false,
        confidence: 0.0,
        outputs: {},
        observations: ['Analytics execution failed: ${e.toString()}'],
        executionTime: DateTime.now().difference(startTime),
      );
    }
  }
}

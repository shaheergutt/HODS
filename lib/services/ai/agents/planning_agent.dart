import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../ai_types.dart';
import '../specialist_agent.dart';
import '../../progress/progress_models.dart';
import '../../progress/progress_event.dart';
import '../../progress/progress_manager.dart';

class PlanningAgent implements SpecialistAgent {
  final GenerativeModel _model;
  final ProgressManager? _progressManager;

  PlanningAgent(this._model, {ProgressManager? progressManager}) : _progressManager = progressManager;

  @override
  AgentCapability get capability => AgentCapability.planning;

  @override
  Future<AgentResult> execute(AgentTask task, ExecutionState state) async {
    final startTime = DateTime.now();

    _progressManager?.emit(ProgressEvent(
      taskId: task.taskId,
      stage: ProgressStage.understandingRequest,
      status: ProgressStatus.started,
      title: 'Planning Agent',
      message: 'Decomposing objectives and planning stages...',
      agentName: 'PlanningAgent',
      timestamp: DateTime.now(),
    ));

    final prompt = '''
You are the HODS Planning Specialist Agent.
Your job is to perform goal decomposition, coordinate multi-step tool sequences, track constraints, and organize planner observations.
You MUST focus only on planning logic. Do NOT generate RAG logic, recommendations, or booking executions directly.

Task Objective: "${task.objective}"
Current Request: "${state.originalRequest}"
Current Iteration: ${state.currentIteration}
Goals Status:
- Pending Goals: ${state.goals.isEmpty ? 'None' : state.goals.where((g) => g.status != 'completed').map((g) => '"${g.description}"').join(', ')}
- Completed Goals: ${state.goals.isEmpty ? 'None' : state.goals.where((g) => g.status == 'completed').map((g) => '"${g.description}"').join(', ')}

Please evaluate the current execution steps and produce a structured evaluation containing:
1. "plannerReasoning": Explaining what goals should be completed next.
2. "goalCompleted": True if all primary goals are completed, false otherwise.
3. "newObservation": General planner observations about constraints or execution.
4. "remainingGoals": Updated pending goals.
5. "completedGoals": Updated completed goals with completion reasons.

Format your output strictly as a JSON object:
{
  "plannerReasoning": "string",
  "goalCompleted": bool,
  "newObservation": "string",
  "remainingGoals": [{"description": "string", "status": "pending", "priority": "medium", "dependencies": []}],
  "completedGoals": [{"description": "string", "status": "completed", "priority": "medium", "dependencies": [], "completionReason": "string"}]
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

      // Merge goals into state
      final List<dynamic> remGoalsData = parsed['remainingGoals'] ?? [];
      final List<dynamic> compGoalsData = parsed['completedGoals'] ?? [];

      final List<Goal> newRemaining = remGoalsData.map((g) => Goal.fromMap(Map<String, dynamic>.from(g))).toList();
      final List<Goal> newCompleted = compGoalsData.map((g) => Goal.fromMap(Map<String, dynamic>.from(g))).toList();

      state.goals.clear();
      state.goals.addAll(newRemaining);
      state.goals.addAll(newCompleted);

      final String observation = parsed['newObservation'] ?? '';
      if (observation.isNotEmpty) {
        state.observations.add(PlannerObservation(
          toolName: 'planning_agent',
          observation: observation,
          timestamp: DateTime.now(),
        ));
      }

      _progressManager?.emit(ProgressEvent(
        taskId: task.taskId,
        stage: ProgressStage.understandingRequest,
        status: ProgressStatus.completed,
        title: 'Planning Agent',
        message: 'Goal structures verified and sequences organized.',
        agentName: 'PlanningAgent',
        timestamp: DateTime.now(),
      ));

      return AgentResult(
        taskId: task.taskId,
        agentName: 'PlanningAgent',
        success: true,
        confidence: 0.95,
        outputs: parsed,
        observations: [parsed['plannerReasoning'] ?? 'Goals evaluated.'],
        executionTime: DateTime.now().difference(startTime),
      );

    } catch (e) {
      _progressManager?.emit(ProgressEvent(
        taskId: task.taskId,
        stage: ProgressStage.understandingRequest,
        status: ProgressStatus.failed,
        severity: ProgressSeverity.error,
        title: 'Planning Agent Failed',
        message: e.toString(),
        agentName: 'PlanningAgent',
        timestamp: DateTime.now(),
      ));

      return AgentResult(
        taskId: task.taskId,
        agentName: 'PlanningAgent',
        success: false,
        confidence: 0.0,
        outputs: {},
        observations: ['Planning failed: ${e.toString()}'],
        executionTime: DateTime.now().difference(startTime),
      );
    }
  }
}

import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../ai_types.dart';
import '../specialist_agent.dart';
import '../recommendation_manager.dart';
import '../../progress/progress_models.dart';
import '../../progress/progress_event.dart';
import '../../progress/progress_manager.dart';

class RecommendationAgent implements SpecialistAgent {
  final GenerativeModel _model;
  final RecommendationManager _recommendationManager;
  final ProgressManager? _progressManager;

  RecommendationAgent(this._model, {RecommendationManager? recommendationManager, ProgressManager? progressManager}) 
      : _recommendationManager = recommendationManager ?? RecommendationManager(_model),
        _progressManager = progressManager;

  @override
  AgentCapability get capability => AgentCapability.recommendation;

  @override
  Future<AgentResult> execute(AgentTask task, ExecutionState state) async {
    final startTime = DateTime.now();

    _progressManager?.emit(ProgressEvent(
      taskId: task.taskId,
      stage: ProgressStage.rankingRecommendations,
      status: ProgressStatus.started,
      title: 'Recommendation Engine',
      message: 'Ranking available hostels...',
      agentName: 'RecommendationAgent',
      timestamp: DateTime.now(),
    ));

    final prompt = '''
You are the HODS Recommendation Specialist Agent.
Your job is to define the recommendation objectives, ranking criteria, and constraints for evaluating hostels.

Task Objective: "${task.objective}"
User Request: "${state.originalRequest}"
Working Memory Facts: ${json.encode(state.workingMemory.toMap())}

Please output a structured recommendation goal. If no recommendations are needed, set "requireRecommendations" to false.

Format your output strictly as a JSON object:
{
  "requireRecommendations": bool,
  "objective": "string",
  "rankingCriteria": ["string"],
  "constraints": ["string"],
  "expectedOutcome": "string"
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

      if (parsed['requireRecommendations'] == true) {
        final recGoal = RecommendationGoal(
          objective: parsed['objective'] ?? 'Find the best hostels',
          rankingCriteria: List<String>.from(parsed['rankingCriteria'] ?? []),
          constraints: List<String>.from(parsed['constraints'] ?? []),
          priority: 'high',
          expectedOutcome: parsed['expectedOutcome'] ?? 'A ranked list of hostels',
        );

        final config = RecommendationConfig(
          scoringWeights: {
            'budget': 0.25,
            'distance': 0.2,
            'rating': 0.2,
            'preferences': 0.25,
            'policy': 0.1,
          },
        );

        _progressManager?.emit(ProgressEvent(
          taskId: task.taskId,
          stage: ProgressStage.rankingRecommendations,
          status: ProgressStatus.running,
          title: 'Recommendation Engine',
          message: 'Comparing ratings and calculating best matches...',
          agentName: 'RecommendationAgent',
          timestamp: DateTime.now(),
        ));

        final recContext = await _recommendationManager.generateRecommendations(
          state,
          recGoal,
          config,
        );

        state.recommendationContext = recContext;

        // Record a step in ExecutionState
        state.steps.add(PlanningStep(
          toolCall: ToolCall(
            toolName: 'recommendation_engine',
            arguments: {'objective': recGoal.objective},
            confidence: 1.0,
            reasoning: 'Scored and ranked hostels based on constraints.',
          ),
          plannerReasoning: 'Recommendation Goal Generated: ${recGoal.objective}',
          observation: 'Recommendations generated with confidence ${recContext.recommendationConfidence.toStringAsFixed(2)}. Tradeoffs: ${recContext.recommendationTradeoffs.join(', ')}',
        ));

        _progressManager?.emit(ProgressEvent(
          taskId: task.taskId,
          stage: ProgressStage.rankingRecommendations,
          status: ProgressStatus.completed,
          title: 'Recommendation Engine',
          message: 'Ranked available hostels against your preferences.',
          agentName: 'RecommendationAgent',
          timestamp: DateTime.now(),
        ));

        return AgentResult(
          taskId: task.taskId,
          agentName: 'RecommendationAgent',
          success: true,
          confidence: recContext.recommendationConfidence,
          outputs: recContext.toMap(),
          observations: [recGoal.objective, 'Generated ${recContext.rankedCandidates.length} ranked hostels.'],
          executionTime: DateTime.now().difference(startTime),
        );
      } else {
        _progressManager?.emit(ProgressEvent(
          taskId: task.taskId,
          stage: ProgressStage.rankingRecommendations,
          status: ProgressStatus.completed,
          title: 'Recommendation Engine',
          message: 'No recommendation scoring required.',
          agentName: 'RecommendationAgent',
          timestamp: DateTime.now(),
        ));

        return AgentResult(
          taskId: task.taskId,
          agentName: 'RecommendationAgent',
          success: true,
          confidence: 1.0,
          outputs: {},
          observations: [parsed['reasoning'] ?? 'No recommendation scoring needed.'],
          executionTime: DateTime.now().difference(startTime),
        );
      }
    } catch (e) {
      _progressManager?.emit(ProgressEvent(
        taskId: task.taskId,
        stage: ProgressStage.rankingRecommendations,
        status: ProgressStatus.failed,
        severity: ProgressSeverity.error,
        title: 'Recommendation Engine Failed',
        message: e.toString(),
        agentName: 'RecommendationAgent',
        timestamp: DateTime.now(),
      ));

      return AgentResult(
        taskId: task.taskId,
        agentName: 'RecommendationAgent',
        success: false,
        confidence: 0.0,
        outputs: {},
        observations: ['Recommendation failed: ${e.toString()}'],
        executionTime: DateTime.now().difference(startTime),
      );
    }
  }
}

import '../ai_types.dart';
import '../specialist_agent.dart';
import '../reflection_manager.dart';
import '../../progress/progress_models.dart';
import '../../progress/progress_event.dart';
import '../../progress/progress_manager.dart';

class ReflectionAgentSpecialist implements SpecialistAgent {
  final ReflectionManager _manager;
  final ProgressManager? _progressManager;

  ReflectionAgentSpecialist(this._manager, {ProgressManager? progressManager}) 
      : _progressManager = progressManager;

  @override
  AgentCapability get capability => AgentCapability.reflection;

  @override
  Future<AgentResult> execute(AgentTask task, ExecutionState state) async {
    final startTime = DateTime.now();

    _progressManager?.emit(ProgressEvent(
      taskId: task.taskId,
      stage: ProgressStage.reflectionVerification,
      status: ProgressStatus.started,
      title: 'Reflection Agent',
      message: 'Verifying all requirements...',
      agentName: 'ReflectionAgentSpecialist',
      timestamp: DateTime.now(),
    ));

    // Call the existing reflection validation flow
    final result = await _manager.reflect(
      state,
      ReflectionMode.finalReview,
      ReflectionConfig(),
    );

    if (result.isComplete) {
      _progressManager?.emit(ProgressEvent(
        taskId: task.taskId,
        stage: ProgressStage.reflectionVerification,
        status: ProgressStatus.completed,
        title: 'Reflection Agent',
        message: 'All constraints and objectives verified successfully.',
        agentName: 'ReflectionAgentSpecialist',
        timestamp: DateTime.now(),
      ));
    } else {
      _progressManager?.emit(ProgressEvent(
        taskId: task.taskId,
        stage: ProgressStage.reflectionVerification,
        status: ProgressStatus.failed,
        severity: ProgressSeverity.warning,
        title: 'Reflection Agent Issues',
        message: result.issues.firstOrNull?.description ?? 'Validation checks flagged repair action.',
        agentName: 'ReflectionAgentSpecialist',
        timestamp: DateTime.now(),
      ));
    }

    return AgentResult(
      taskId: task.taskId,
      agentName: 'ReflectionAgent',
      success: result.isComplete,
      confidence: result.reflectionConfidence,
      outputs: result.toMap(),
      observations: [
        'isComplete: ${result.isComplete}',
        if (result.issues.isNotEmpty) 'Issues: ${result.issues.map((i) => i.description).join('; ')}'
      ],
      executionTime: DateTime.now().difference(startTime),
    );
  }
}

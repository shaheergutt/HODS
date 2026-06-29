import '../ai_types.dart';
import '../specialist_agent.dart';
import '../memory_manager.dart';
import '../../progress/progress_models.dart';
import '../../progress/progress_event.dart';
import '../../progress/progress_manager.dart';

class MemoryAgent implements SpecialistAgent {
  final MemoryManager _memoryManager;
  final ProgressManager? _progressManager;

  MemoryAgent({MemoryManager? memoryManager, ProgressManager? progressManager}) 
      : _memoryManager = memoryManager ?? MemoryManager(),
        _progressManager = progressManager;

  @override
  AgentCapability get capability => AgentCapability.memory;

  @override
  Future<AgentResult> execute(AgentTask task, ExecutionState state) async {
    final startTime = DateTime.now();
    final String userId = task.requiredInputs['userId']?.toString() ?? 'system_user';

    _progressManager?.emit(ProgressEvent(
      taskId: task.taskId,
      stage: ProgressStage.loadingPreferences,
      status: ProgressStatus.started,
      title: 'Memory Agent',
      message: 'Loading your saved preferences...',
      agentName: 'MemoryAgent',
      timestamp: DateTime.now(),
    ));

    try {
      final memoryContext = await _memoryManager.retrieveMemoryContext(userId, MemoryRetrievalConfig());
      state.memoryContext = memoryContext;

      // Merge context to working memory
      _memoryManager.mergeToWorkingMemory(memoryContext, state.workingMemory);

      _progressManager?.emit(ProgressEvent(
        taskId: task.taskId,
        stage: ProgressStage.loadingPreferences,
        status: ProgressStatus.completed,
        title: 'Memory Agent',
        message: 'Loaded user preferences and long-term context.',
        agentName: 'MemoryAgent',
        timestamp: DateTime.now(),
      ));

      return AgentResult(
        taskId: task.taskId,
        agentName: 'MemoryAgent',
        success: true,
        confidence: 1.0,
        outputs: {
          'preferencesCount': memoryContext.preferences.length,
          'factsCount': memoryContext.userFacts.length,
          'summariesCount': memoryContext.conversationSummaries.length,
        },
        observations: ['Long-term memory context successfully retrieved and merged for user $userId.'],
        executionTime: DateTime.now().difference(startTime),
      );

    } catch (e) {
      _progressManager?.emit(ProgressEvent(
        taskId: task.taskId,
        stage: ProgressStage.loadingPreferences,
        status: ProgressStatus.failed,
        severity: ProgressSeverity.error,
        title: 'Memory Agent Failed',
        message: e.toString(),
        agentName: 'MemoryAgent',
        timestamp: DateTime.now(),
      ));

      return AgentResult(
        taskId: task.taskId,
        agentName: 'MemoryAgent',
        success: false,
        confidence: 0.0,
        outputs: {},
        observations: ['Memory retrieval failed: ${e.toString()}'],
        executionTime: DateTime.now().difference(startTime),
      );
    }
  }
}

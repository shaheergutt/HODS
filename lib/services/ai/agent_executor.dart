import 'dart:async';
import 'ai_types.dart';
import 'agent_registry.dart';
import 'collaboration_logger.dart';

class AgentExecutor {
  final CollaborationLogger _logger;

  AgentExecutor({CollaborationLogger? logger}) 
      : _logger = logger ?? CollaborationLogger();

  /// Executes a task using a registered specialist agent with retries and timeout constraints.
  Future<AgentResult> executeTask(
    AgentTask task,
    ExecutionState state, {
    Duration timeout = const Duration(seconds: 10),
    int maxRetries = 3,
  }) async {
    _logger.logTaskStart(task);
    final startTime = DateTime.now();

    final specialist = AgentRegistry.getAgent(task.targetAgent);
    if (specialist == null) {
      final failResult = AgentResult(
        taskId: task.taskId,
        agentName: task.targetAgent.name,
        success: false,
        confidence: 0.0,
        outputs: {},
        observations: ['No registered specialist agent found for capability ${task.targetAgent.name}'],
        executionTime: DateTime.now().difference(startTime),
      );
      _logger.logTaskResult(failResult);
      return failResult;
    }

    int attempt = 0;
    while (attempt < maxRetries) {
      attempt++;
      try {
        final Future<AgentResult> executionFuture = specialist.execute(task, state);
        
        final AgentResult result = await executionFuture.timeout(timeout);
        _logger.logTaskResult(result);
        return result;

      } on TimeoutException catch (_) {
        _logger.logTimeout(task.taskId);
        if (attempt >= maxRetries) {
          final timeoutResult = AgentResult(
            taskId: task.taskId,
            agentName: specialist.runtimeType.toString(),
            success: false,
            confidence: 0.0,
            outputs: {},
            observations: ['Timeout exceeded after $maxRetries attempts'],
            executionTime: DateTime.now().difference(startTime),
          );
          _logger.logTaskResult(timeoutResult);
          return timeoutResult;
        }
      } catch (e) {
        _logger.logRetry(task.taskId, attempt, e.toString());
        if (attempt >= maxRetries) {
          final errorResult = AgentResult(
            taskId: task.taskId,
            agentName: specialist.runtimeType.toString(),
            success: false,
            confidence: 0.0,
            outputs: {},
            observations: ['Failed: ${e.toString()}'],
            executionTime: DateTime.now().difference(startTime),
          );
          _logger.logTaskResult(errorResult);
          return errorResult;
        }
        // Small dynamic delay prior to retry
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      }
    }

    return AgentResult(
      taskId: task.taskId,
      agentName: specialist.runtimeType.toString(),
      success: false,
      confidence: 0.0,
      outputs: {},
      observations: ['Execution fell through retry loop.'],
      executionTime: DateTime.now().difference(startTime),
    );
  }
}

import 'dart:developer' as developer;
import 'ai_types.dart';

class CollaborationLogger {
  void logCollaborationStart(String originalRequest) {
    developer.log(
      '[MultiAgentFramework] Collaboration started for request: "$originalRequest"',
      name: 'CollaborationLogger',
    );
  }

  void logTaskStart(AgentTask task) {
    developer.log(
      '[MultiAgentFramework] Task ${task.taskId} started -> Agent: ${task.targetAgent.name} | Objective: ${task.objective}',
      name: 'CollaborationLogger',
    );
  }

  void logTaskResult(AgentResult result) {
    developer.log(
      '[MultiAgentFramework] Task ${result.taskId} finished -> Success: ${result.success} | Confidence: ${result.confidence.toStringAsFixed(2)} | Latency: ${result.executionTime.inMilliseconds}ms',
      name: 'CollaborationLogger',
    );
    if (result.observations.isNotEmpty) {
      developer.log(
        '  - Observations: ${result.observations.join('; ')}',
        name: 'CollaborationLogger',
      );
    }
  }

  void logRetry(String taskId, int attempt, String error) {
    developer.log(
      '[MultiAgentFramework] Task $taskId failed, retrying (Attempt $attempt) -> Error: $error',
      name: 'CollaborationLogger',
      level: 900,
    );
  }

  void logTimeout(String taskId) {
    developer.log(
      '[MultiAgentFramework] Task $taskId TIMEOUT exceeded!',
      name: 'CollaborationLogger',
      level: 900,
    );
  }

  void logConflict(String conflictDescription, String resolvedOutcome) {
    developer.log(
      '[MultiAgentFramework] Conflict detected: $conflictDescription | Resolved to: $resolvedOutcome',
      name: 'CollaborationLogger',
      level: 900,
    );
  }

  void logCollaborationEnd(CollaborationState state, int elapsedMs) {
    developer.log(
      '[MultiAgentFramework] Collaboration complete in ${elapsedMs}ms.',
      name: 'CollaborationLogger',
    );
    developer.log(
      '[MultiAgentFramework] Completed Tasks: ${state.completedTasks.map((t) => '${t.targetAgent.name} (${t.taskId})').join(', ')}',
      name: 'CollaborationLogger',
    );
    if (state.failedTasks.isNotEmpty) {
      developer.log(
        '[MultiAgentFramework] Failed Tasks: ${state.failedTasks.map((t) => '${t.targetAgent.name} (${t.taskId})').join(', ')}',
        name: 'CollaborationLogger',
        level: 900,
      );
    }
  }
}

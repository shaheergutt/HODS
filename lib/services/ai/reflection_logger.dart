import 'dart:developer' as developer;
import 'ai_types.dart';

class ReflectionLogger {
  /// Logs the start of a reflection cycle.
  void logReflectionStart(ReflectionMode mode, int currentIteration) {
    developer.log(
      '[ReflectionEngine] Starting ${mode.name} reflection for iteration $currentIteration.',
      name: 'ReflectionLogger',
    );
  }

  /// Logs the final ReflectionResult, focusing on issues, confidence, and recommended actions.
  void logReflectionResult(ReflectionResult result, int elapsedMilliseconds) {
    developer.log(
      '[ReflectionEngine] Reflection completed in ${elapsedMilliseconds}ms.',
      name: 'ReflectionLogger',
    );
    developer.log(
      '[ReflectionEngine] Mode: ${result.reflectionMode.name} | isComplete: ${result.isComplete} | Action: ${result.recommendedAction.name}',
      name: 'ReflectionLogger',
    );
    developer.log(
      '[ReflectionEngine] Confidence -> Planner: ${result.plannerConfidence.toStringAsFixed(2)} | Reflection: ${result.reflectionConfidence.toStringAsFixed(2)}',
      name: 'ReflectionLogger',
    );
    developer.log(
      '[ReflectionEngine] Scores -> Goal: ${result.verificationScore.goalScore.toStringAsFixed(2)} | Constraint: ${result.verificationScore.constraintScore.toStringAsFixed(2)} | Knowledge: ${result.verificationScore.knowledgeScore.toStringAsFixed(2)} | Tool: ${result.verificationScore.toolCoverageScore.toStringAsFixed(2)} | Rec: ${result.verificationScore.recommendationScore.toStringAsFixed(2)} | Memory: ${result.verificationScore.memoryScore.toStringAsFixed(2)} | Overall: ${result.verificationScore.overallScore.toStringAsFixed(2)}',
      name: 'ReflectionLogger',
    );
    developer.log(
      '[ReflectionEngine] Goals -> Satisfied: ${result.satisfiedGoals.join(', ')} | Missing: ${result.missingGoals.join(', ')}',
      name: 'ReflectionLogger',
    );
    if (result.violatedConstraints.isNotEmpty) {
      developer.log(
        '[ReflectionEngine] Constraints Violated: ${result.violatedConstraints.join(', ')}',
        name: 'ReflectionLogger',
        level: 900,
      );
    }
    if (result.contradictions.isNotEmpty) {
      developer.log(
        '[ReflectionEngine] Contradictions Found: ${result.contradictions.join(', ')}',
        name: 'ReflectionLogger',
        level: 900,
      );
    }
    if (result.stopReason.isNotEmpty) {
      developer.log(
        '[ReflectionEngine] Stop Reason: ${result.stopReason}',
        name: 'ReflectionLogger',
      );
    }

    if (result.issues.isNotEmpty) {
      developer.log(
        '[ReflectionEngine] Found ${result.issues.length} issues:',
        name: 'ReflectionLogger',
      );
      for (var issue in result.issues) {
        final hints = [
          if (issue.toolHint != null) 'ToolHint: ${issue.toolHint}',
          if (issue.knowledgeQuery != null) 'KnowledgeQuery: ${issue.knowledgeQuery}',
          if (issue.plannerGoal != null) 'PlannerGoal: ${issue.plannerGoal}',
        ].join(', ');
        developer.log(
          '  - [${issue.severity.name.toUpperCase()}] ${issue.issueType}: ${issue.description} (Fix: ${issue.suggestedFix}${hints.isNotEmpty ? '; $hints' : ''})',
          name: 'ReflectionLogger',
        );
      }
    }
  }

  /// Logs auto-repair triggers.
  void logAutoRepair(ReflectionAction action, String reason) {
    developer.log(
      '[ReflectionEngine] Triggering Auto-Repair -> Action: ${action.name} | Reason: $reason',
      name: 'ReflectionLogger',
      level: 900, // Warning level conceptually
    );
  }
}

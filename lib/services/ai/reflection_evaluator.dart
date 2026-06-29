import 'dart:math';
import 'ai_types.dart';

class ReflectionEvaluator {
  /// Evaluates the raw mapped data from the LLM to determine the final VerificationScore
  /// and the recommended ReflectionAction.
  static ReflectionResult evaluate(
    Map<String, dynamic> rawLlmOutput,
    ReflectionMode mode,
    ReflectionConfig config,
  ) {
    final issuesData = (rawLlmOutput['issues'] as List?) ?? [];
    final List<ReflectionIssue> issues = issuesData.map((i) {
      final map = Map<String, dynamic>.from(i);
      return ReflectionIssue(
        issueType: map['issueType']?.toString() ?? 'Unknown',
        severity: _parseSeverity(map['severity']?.toString() ?? 'low'),
        description: map['description']?.toString() ?? '',
        affectedGoal: map['affectedGoal']?.toString() ?? '',
        suggestedFix: map['suggestedFix']?.toString() ?? '',
        toolHint: map['toolHint']?.toString(),
        knowledgeQuery: map['knowledgeQuery']?.toString(),
        plannerGoal: map['plannerGoal']?.toString(),
      );
    }).toList();

    // Determine verification scores based on issues and configurations
    final VerificationScore score = _computeScores(issues, rawLlmOutput, config);
    
    // Determine the highest severity among issues
    var maxSeverity = ReflectionSeverity.low;
    for (var issue in issues) {
      if (issue.severity.index > maxSeverity.index) {
        maxSeverity = issue.severity;
      }
    }

    // Determine recommended action based on mode, severity, and issues
    ReflectionAction recommendedAction = ReflectionAction.continuePlanning;
    bool isComplete = rawLlmOutput['isComplete'] ?? false;

    if (maxSeverity == ReflectionSeverity.critical) {
      if (issues.any((i) => i.issueType == 'ClarificationRequired')) {
        recommendedAction = ReflectionAction.askUserClarification;
      } else {
        recommendedAction = ReflectionAction.terminate;
      }
      isComplete = false;
    } else if (maxSeverity == ReflectionSeverity.high || maxSeverity == ReflectionSeverity.medium) {
      // Find what type of fix is suggested
      if (issues.any((i) => i.issueType == 'MissingToolExecution')) {
        recommendedAction = ReflectionAction.executeTool;
      } else if (issues.any((i) => i.issueType == 'MissingKnowledge' || i.issueType == 'KnowledgeConflict')) {
        recommendedAction = ReflectionAction.retrieveKnowledge;
      } else if (issues.any((i) => i.issueType == 'RecommendationConflict')) {
        recommendedAction = ReflectionAction.reRankRecommendations;
      } else if (issues.any((i) => i.issueType == 'ClarificationRequired')) {
        recommendedAction = ReflectionAction.askUserClarification;
      } else {
        recommendedAction = ReflectionAction.continuePlanning;
      }
      isComplete = false;
    } else {
      if (mode == ReflectionMode.finalReview && isComplete) {
        recommendedAction = ReflectionAction.generateResponse;
      }
    }

    // Force failure if minimum confidence is not met
    final double reflectionConfidence = (rawLlmOutput['reflectionConfidence'] ?? 1.0).toDouble();
    if (reflectionConfidence < config.minimumConfidence) {
      isComplete = false;
      if (recommendedAction == ReflectionAction.generateResponse || recommendedAction == ReflectionAction.continuePlanning) {
        recommendedAction = ReflectionAction.executeTool; // Default to gathering more data if unconfident
      }
    }

    return ReflectionResult(
      isComplete: isComplete,
      reflectionMode: mode,
      plannerConfidence: (rawLlmOutput['plannerConfidence'] ?? 1.0).toDouble(),
      reflectionConfidence: reflectionConfidence,
      verificationScore: score,
      issues: issues,
      recommendedAction: recommendedAction,
      stopReason: rawLlmOutput['stopReason']?.toString() ?? '',
      satisfiedGoals: List<String>.from(rawLlmOutput['satisfiedGoals'] ?? []),
      missingGoals: List<String>.from(rawLlmOutput['missingGoals'] ?? []),
      violatedConstraints: List<String>.from(rawLlmOutput['violatedConstraints'] ?? []),
      contradictions: List<String>.from(rawLlmOutput['contradictions'] ?? []),
    );
  }

  static ReflectionSeverity _parseSeverity(String sev) {
    switch (sev.toLowerCase()) {
      case 'critical': return ReflectionSeverity.critical;
      case 'high': return ReflectionSeverity.high;
      case 'medium': return ReflectionSeverity.medium;
      case 'low': 
      default:
        return ReflectionSeverity.low;
    }
  }

  static VerificationScore _computeScores(List<ReflectionIssue> issues, Map<String, dynamic> raw, ReflectionConfig config) {
    // Helper to calculate penalizations for a given category keyword
    double penalize(String typeKeyword) {
      double score = 1.0;
      for (var issue in issues) {
        if (issue.issueType.toLowerCase().contains(typeKeyword.toLowerCase()) || 
            issue.description.toLowerCase().contains(typeKeyword.toLowerCase())) {
          if (issue.severity == ReflectionSeverity.critical) {
            score -= 0.5;
          } else if (issue.severity == ReflectionSeverity.high) {
            score -= 0.3;
          } else if (issue.severity == ReflectionSeverity.medium) {
            score -= 0.15;
          } else {
            score -= 0.05;
          }
        }
      }
      return max(0.0, score);
    }

    final goalScore = penalize('Goal');
    
    // Verify properties against active configurations
    final constraintScore = config.verifyConstraints ? penalize('Constraint') : 1.0;
    final knowledgeScore = config.verifyKnowledgeConsistency 
        ? min(penalize('Knowledge'), penalize('Conflict')) 
        : 1.0;
    final toolScore = config.verifyToolCoverage ? penalize('Tool') : 1.0;
    final recScore = config.verifyRecommendations ? penalize('Recommendation') : 1.0;
    final memoryScore = config.verifyMemory ? penalize('Memory') : 1.0;
    
    final overall = (goalScore + constraintScore + knowledgeScore + toolScore + recScore + memoryScore) / 6.0;

    return VerificationScore(
      goalScore: goalScore,
      constraintScore: constraintScore,
      knowledgeScore: knowledgeScore,
      toolCoverageScore: toolScore,
      recommendationScore: recScore,
      memoryScore: memoryScore,
      overallScore: overall,
    );
  }
}

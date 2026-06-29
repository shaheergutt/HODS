import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_types.dart';
import 'reflection_agent.dart';
import 'reflection_logger.dart';

class ReflectionManager {
  final ReflectionAgent _agent;
  final ReflectionLogger _logger;
  
  int _reflectionCycles = 0;
  final List<ReflectionResult> _history = [];

  ReflectionManager(GenerativeModel model) 
      : _agent = ReflectionAgent(model),
        _logger = ReflectionLogger();

  /// Resets the reflection engine state for a new planning session.
  void reset() {
    _reflectionCycles = 0;
    _history.clear();
  }

  /// Invokes a reflection cycle against the current ExecutionState.
  Future<ReflectionResult> reflect(
    ExecutionState state,
    ReflectionMode mode,
    ReflectionConfig config,
  ) async {
    final startTime = DateTime.now();
    _logger.logReflectionStart(mode, state.currentIteration);

    // Prevent infinite auto-repair loops
    if (_reflectionCycles >= config.maximumReflectionCycles && mode == ReflectionMode.finalReview) {
      final result = ReflectionResult(
        isComplete: true, // Force complete to break the loop
        reflectionMode: mode,
        plannerConfidence: state.plannerConfidenceHistory.isNotEmpty ? state.plannerConfidenceHistory.last : 0.5,
        reflectionConfidence: state.reflectionConfidenceHistory.isNotEmpty ? state.reflectionConfidenceHistory.last : 0.5,
        verificationScore: VerificationScore(),
        issues: [
          ReflectionIssue(
            issueType: 'SafetyLimitReached',
            severity: ReflectionSeverity.medium,
            description: 'Maximum reflection auto-repair cycles (${config.maximumReflectionCycles}) reached. Terminating.',
            affectedGoal: 'System Stability',
            suggestedFix: 'None. Proceeding with best-effort response.',
          )
        ],
        stopReason: 'MaxReflectionCyclesReached',
        recommendedAction: ReflectionAction.generateResponse,
      );
      _logger.logReflectionResult(result, DateTime.now().difference(startTime).inMilliseconds);
      state.reflectionResult = result;
      return result;
    }

    // Call the Agent to analyze current state
    var result = await _agent.reflect(state, mode, config);

    // Record confidence histories
    state.plannerConfidenceHistory.add(result.plannerConfidence);
    state.reflectionConfidenceHistory.add(result.reflectionConfidence);

    // Check confidence stabilization
    if (_isConfidenceStabilized(state.plannerConfidenceHistory) && 
        _isConfidenceStabilized(state.reflectionConfidenceHistory)) {
      result = ReflectionResult(
        isComplete: true,
        reflectionMode: mode,
        plannerConfidence: result.plannerConfidence,
        reflectionConfidence: result.reflectionConfidence,
        verificationScore: result.verificationScore,
        issues: result.issues,
        stopReason: 'ConfidenceStabilized',
        recommendedAction: ReflectionAction.generateResponse,
        satisfiedGoals: result.satisfiedGoals,
        missingGoals: result.missingGoals,
        violatedConstraints: result.violatedConstraints,
        contradictions: result.contradictions,
      );
      _logger.logReflectionResult(result, DateTime.now().difference(startTime).inMilliseconds);
      state.reflectionResult = result;
      return result;
    }

    // Duplicate reflection detection
    if (_history.isNotEmpty) {
      final lastResult = _history.last;
      if (_isDuplicate(result, lastResult)) {
        final duplicateResult = ReflectionResult(
          isComplete: true, // Force complete to break loop
          reflectionMode: mode,
          plannerConfidence: result.plannerConfidence,
          reflectionConfidence: result.reflectionConfidence,
          verificationScore: result.verificationScore,
          issues: result.issues,
          stopReason: 'DuplicateReflectionDetected',
          recommendedAction: ReflectionAction.generateResponse,
          satisfiedGoals: result.satisfiedGoals,
          missingGoals: result.missingGoals,
          violatedConstraints: result.violatedConstraints,
          contradictions: result.contradictions,
        );
        _logger.logReflectionResult(duplicateResult, DateTime.now().difference(startTime).inMilliseconds);
        state.reflectionResult = duplicateResult;
        return duplicateResult;
      }
    }

    // Add to history
    _history.add(result);

    // Track cycle count for final review auto-repairs
    if (mode == ReflectionMode.finalReview && !result.isComplete) {
      _reflectionCycles++;
      _logger.logAutoRepair(result.recommendedAction, result.issues.firstOrNull?.description ?? 'Unknown issue');
    }

    _logger.logReflectionResult(result, DateTime.now().difference(startTime).inMilliseconds);
    
    // Store globally in state for downstream (ResponseGenerator) usage
    state.reflectionResult = result;

    return result;
  }

  bool _isDuplicate(ReflectionResult r1, ReflectionResult r2) {
    if (r1.issues.length != r2.issues.length) return false;
    for (var iss1 in r1.issues) {
      final match = r2.issues.any((iss2) =>
          iss2.issueType == iss1.issueType &&
          iss2.affectedGoal == iss1.affectedGoal &&
          iss2.suggestedFix == iss1.suggestedFix);
      if (!match) return false;
    }
    return true;
  }

  bool _isConfidenceStabilized(List<double> history) {
    if (history.length < 3) return false;
    final last = history.last;
    final prev = history[history.length - 2];
    final prevPrev = history[history.length - 3];
    return (last - prev).abs() < 0.05 && (prev - prevPrev).abs() < 0.05;
  }
}

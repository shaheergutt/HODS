import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_types.dart';
import 'candidate_extraction.dart';
import 'recommendation_scoring_engine.dart';
import 'recommendation_ranking_engine.dart';
import 'recommendation_reviewer.dart';

class RecommendationManager {
  final RecommendationReviewer _reviewer;
  
  RecommendationManager(GenerativeModel model) : _reviewer = RecommendationReviewer(model);

  /// Orchestrates the entire recommendation pipeline: Extraction -> Scoring -> Ranking -> Review
  Future<RecommendationContext> generateRecommendations(
    ExecutionState state,
    RecommendationGoal goal,
    RecommendationConfig config,
  ) async {
    // 1. Extract raw candidates
    final rawCandidates = CandidateExtraction.extractCandidates(state);
    if (rawCandidates.isEmpty) {
      return RecommendationContext(
        recommendationReasoning: 'Could not find any hostels in recent search history to recommend.',
        recommendationConfidence: 0.0,
      );
    }

    // 2. Score candidates deterministically
    final scoredCandidates = RecommendationScoringEngine.scoreCandidates(
      rawCandidates,
      config,
      MemoryContext(
        preferences: state.recommendationContext.rankedCandidates.isEmpty 
          ? [] 
          : [], // This would ideally pull from the actual memory context.
      ), // In a real flow, memoryContext is injected from higher up or available in ExecutionState
      state.knowledgeContext,
      state.workingMemory,
    );

    // 3. Rank and limit candidates
    final rankedCandidates = RecommendationRankingEngine.rankCandidates(
      scoredCandidates,
      config,
    );

    // 4. Optional LLM Review
    if (config.enableLLMReview) {
      // Create a mock memory context if it isn't passed in directly 
      // (in production, we'll fetch it from the caller, but here we'll assume it's passed or available)
      return await _reviewer.reviewRecommendations(
        rankedCandidates,
        goal,
        MemoryContext(), // Replace with actual MemoryContext passed by PlannerAgent
        state.knowledgeContext,
        state.workingMemory,
      );
    }

    // Return deterministic only
    return RecommendationContext(
      rankedCandidates: rankedCandidates,
      recommendationReasoning: 'Top hostels based on mathematical scoring.',
    );
  }
}

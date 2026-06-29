import 'ai_types.dart';

class RecommendationRankingEngine {
  /// Sorts, filters, and ranks the scored candidates.
  static List<RecommendationCandidate> rankCandidates(
    List<RecommendationCandidate> candidates,
    RecommendationConfig config,
  ) {
    // 1. Filter out those below minimum score
    var ranked = candidates.where((c) => c.totalScore >= config.minimumScore).toList();

    // 2. Sort by totalScore descending
    ranked.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    // 3. Limit to maxRecommendations
    if (ranked.length > config.maxRecommendations) {
      ranked = ranked.sublist(0, config.maxRecommendations);
    }

    return ranked;
  }
}

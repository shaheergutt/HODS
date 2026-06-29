import 'dart:math';
import 'ai_types.dart';

class RecommendationScoringEngine {
  /// Deterministically calculates scores for a list of hostel candidates.
  static List<RecommendationCandidate> scoreCandidates(
    List<Map<String, dynamic>> rawCandidates,
    RecommendationConfig config,
    MemoryContext memoryContext,
    KnowledgeContext knowledgeContext,
    WorkingMemory workingMemory,
  ) {
    return rawCandidates.map((raw) {
      final String id = raw['id']?.toString() ?? raw['hostelId']?.toString() ?? 'unknown';
      final String name = raw['name']?.toString() ?? raw['hostelName']?.toString() ?? 'Unknown Hostel';

      final List<RecommendationScore> breakdowns = [];
      double totalScore = 0.0;

      // 1. Budget Score
      final budgetWeight = config.scoringWeights['budget'] ?? 0.25;
      final budgetScore = _calculateBudgetScore(raw, workingMemory);
      breakdowns.add(RecommendationScore(
        criterion: 'Budget Compatibility',
        weight: budgetWeight,
        rawScore: budgetScore,
        weightedScore: budgetScore * budgetWeight,
        explanation: 'Hostel price alignment with target budget.',
      ));
      totalScore += budgetScore * budgetWeight;

      // 2. Rating Score
      final ratingWeight = config.scoringWeights['rating'] ?? 0.2;
      final ratingScore = _calculateRatingScore(raw);
      breakdowns.add(RecommendationScore(
        criterion: 'Overall Rating',
        weight: ratingWeight,
        rawScore: ratingScore,
        weightedScore: ratingScore * ratingWeight,
        explanation: 'Based on overall user ratings.',
      ));
      totalScore += ratingScore * ratingWeight;

      // 3. Distance Score
      final distanceWeight = config.scoringWeights['distance'] ?? 0.2;
      final distanceScore = _calculateDistanceScore(raw, workingMemory);
      breakdowns.add(RecommendationScore(
        criterion: 'Distance',
        weight: distanceWeight,
        rawScore: distanceScore,
        weightedScore: distanceScore * distanceWeight,
        explanation: 'Proximity to preferred location/university.',
      ));
      totalScore += distanceScore * distanceWeight;

      // 4. Preferences Score
      final prefWeight = config.scoringWeights['preferences'] ?? 0.25;
      final prefScore = _calculatePreferenceScore(raw, memoryContext);
      breakdowns.add(RecommendationScore(
        criterion: 'User Preferences',
        weight: prefWeight,
        rawScore: prefScore,
        weightedScore: prefScore * prefWeight,
        explanation: 'Matches learned preferences (e.g., room type, amenities).',
      ));
      totalScore += prefScore * prefWeight;

      // 5. Knowledge/Policy Conflict Penalty (Negative or neutral)
      final policyWeight = config.scoringWeights['policy'] ?? 0.1;
      final policyScore = _calculatePolicyPenalty(raw, knowledgeContext);
      breakdowns.add(RecommendationScore(
        criterion: 'Policy Compatibility',
        weight: policyWeight,
        rawScore: policyScore,
        weightedScore: policyScore * policyWeight,
        explanation: policyScore < 0.5 ? 'Conflicts with retrieved domain policies.' : 'Complies with general policies.',
      ));
      totalScore += policyScore * policyWeight;

      return RecommendationCandidate(
        hostelId: id,
        hostelName: name,
        hostelData: raw,
        scoreBreakdown: breakdowns,
        totalScore: totalScore,
      );
    }).toList();
  }

  static double _calculateBudgetScore(Map<String, dynamic> raw, WorkingMemory workingMemory) {
    final double targetBudget = double.tryParse(workingMemory.facts['budget']?.toString() ?? '') ?? 0.0;
    final double price = double.tryParse(raw['price']?.toString() ?? raw['rent']?.toString() ?? '0') ?? 0.0;
    
    if (targetBudget <= 0 || price <= 0) return 0.5; // Neutral if unknown

    if (price <= targetBudget) {
      return 1.0; // Perfect within budget
    } else {
      // Exponential penalty for being over budget
      final diff = price - targetBudget;
      final penalty = diff / targetBudget;
      return max(0.0, 1.0 - penalty);
    }
  }

  static double _calculateRatingScore(Map<String, dynamic> raw) {
    final double rating = double.tryParse(raw['rating']?.toString() ?? '0') ?? 0.0;
    return (rating / 5.0).clamp(0.0, 1.0);
  }

  static double _calculateDistanceScore(Map<String, dynamic> raw, WorkingMemory workingMemory) {
    final double distance = double.tryParse(raw['distance']?.toString() ?? '0') ?? 5.0;
    // Assuming closer to 0 is better, max reasonable distance is ~15km
    return max(0.0, 1.0 - (distance / 15.0));
  }

  static double _calculatePreferenceScore(Map<String, dynamic> raw, MemoryContext context) {
    if (context.preferences.isEmpty) return 0.5; // Neutral
    
    double totalPrefScore = 0.0;
    double totalWeight = 0.0;

    for (var pref in context.preferences) {
      final confidence = pref.confidence;
      totalWeight += confidence;

      // Basic matching logic
      final hostelString = raw.toString().toLowerCase();
      final prefValueString = pref.value.toString().toLowerCase();

      if (hostelString.contains(prefValueString)) {
        totalPrefScore += 1.0 * confidence;
      }
    }

    if (totalWeight == 0) return 0.5;
    return (totalPrefScore / totalWeight).clamp(0.0, 1.0);
  }

  static double _calculatePolicyPenalty(Map<String, dynamic> raw, KnowledgeContext context) {
    if (context.retrievedChunks.isEmpty) return 1.0; // No conflicts
    
    // Simple heuristic: if the hostel description conflicts with the policy (like "no monthlies")
    // A robust approach involves an LLM, but this is the deterministic pass.
    // For now, return 1.0 unless we detect obvious constraint strings in the data.
    return 1.0; 
  }
}

import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_types.dart';

class RecommendationReviewer {
  final GenerativeModel _model;

  RecommendationReviewer(this._model);

  /// Invokes Gemini to review deterministic rankings and append qualitative strengths,
  /// weaknesses, and human-friendly recommendation reasoning.
  Future<RecommendationContext> reviewRecommendations(
    List<RecommendationCandidate> rankedCandidates,
    RecommendationGoal goal,
    MemoryContext memoryContext,
    KnowledgeContext knowledgeContext,
    WorkingMemory workingMemory,
  ) async {
    if (rankedCandidates.isEmpty) {
      return RecommendationContext(
        rankedCandidates: [],
        recommendationReasoning: 'No hostels met the minimum criteria for recommendation.',
        recommendationConfidence: 1.0,
      );
    }

    final schema = Schema.object(
      properties: {
        'overallReasoning': Schema.string(description: 'General explanation of why these hostels are recommended, highlighting tradeoffs.'),
        'overallConfidence': Schema.number(description: 'Confidence in this recommendation set (0.0 to 1.0).'),
        'tradeoffs': Schema.array(description: 'List of trade-offs between the top choices', items: Schema.string()),
        'reviewedCandidates': Schema.array(
          description: 'The candidates with qualitative reviews attached.',
          items: Schema.object(
            properties: {
              'hostelId': Schema.string(description: 'The ID of the hostel'),
              'strengths': Schema.array(description: 'List of qualitative strengths', items: Schema.string()),
              'weaknesses': Schema.array(description: 'List of qualitative weaknesses or policy warnings', items: Schema.string()),
            },
            requiredProperties: ['hostelId', 'strengths', 'weaknesses'],
          ),
        ),
      },
      requiredProperties: ['overallReasoning', 'overallConfidence', 'tradeoffs', 'reviewedCandidates'],
    );

    final String prompt = '''
You are the HODS AI Recommendation Reviewer.
Your job is to review a list of mathematically ranked hostels and generate human-friendly qualitative summaries (strengths, weaknesses, and tradeoffs).
DO NOT change the ranking order or the total scores.

Recommendation Goal:
- Objective: ${goal.objective}
- Criteria: ${goal.rankingCriteria.join(', ')}
- Constraints: ${goal.constraints.join(', ')}

User Preferences (MemoryContext):
${memoryContext.preferences.map((p) => '${p.key}: ${p.value}').join(', ')}

Knowledge Policies (KnowledgeContext):
${knowledgeContext.retrievedChunks.map((c) => c.chunk.content).join('\n')}

Working Memory:
${json.encode(workingMemory.toMap())}

Ranked Candidates Data:
${rankedCandidates.map((c) => 'Hostel ID: ${c.hostelId}, Name: ${c.hostelName}, Total Score: ${c.totalScore.toStringAsFixed(2)}\nData: ${json.encode(c.hostelData)}').join('\n\n')}

Identify strengths and weaknesses for each candidate. Identify overall trade-offs (e.g. "Hostel A is cheaper but Hostel B is closer").
''';

    try {
      final response = await _model.generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: schema,
        ),
      );

      final text = response.text?.trim() ?? '{}';
      var cleanText = text;
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll('```json', '').replaceAll('```', '').trim();
      }
      final parsed = json.decode(cleanText) as Map<String, dynamic>;

      final reviewedList = parsed['reviewedCandidates'] as List? ?? [];
      final reviewMap = {
        for (var item in reviewedList)
          item['hostelId'].toString(): item
      };

      // Merge reviews back into candidates
      final enrichedCandidates = rankedCandidates.map((c) {
        final review = reviewMap[c.hostelId];
        return RecommendationCandidate(
          hostelId: c.hostelId,
          hostelName: c.hostelName,
          hostelData: c.hostelData,
          scoreBreakdown: c.scoreBreakdown,
          totalScore: c.totalScore,
          strengths: List<String>.from(review?['strengths'] ?? []),
          weaknesses: List<String>.from(review?['weaknesses'] ?? []),
        );
      }).toList();

      return RecommendationContext(
        rankedCandidates: enrichedCandidates,
        recommendationReasoning: parsed['overallReasoning'] ?? '',
        recommendationConfidence: (parsed['overallConfidence'] ?? 1.0).toDouble(),
        recommendationTradeoffs: List<String>.from(parsed['tradeoffs'] ?? []),
      );

    } catch (e) {
      // Fallback if LLM fails, return deterministic only
      return RecommendationContext(
        rankedCandidates: rankedCandidates,
        recommendationReasoning: 'Mathematically ranked candidates based on constraints.',
        recommendationConfidence: 0.8,
      );
    }
  }
}

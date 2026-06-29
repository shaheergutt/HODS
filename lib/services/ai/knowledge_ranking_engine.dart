import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_types.dart';

class KnowledgeRankingEngine {
  final GenerativeModel _model;

  KnowledgeRankingEngine(this._model);

  Future<List<RetrievalResult>> rank(
    List<KnowledgeChunk> candidates,
    String queryText,
    String retrievalReason,
    KnowledgeRetrievalConfig config,
  ) async {
    if (candidates.isEmpty) return [];

    final candidatesText = candidates.map((c) {
      return '''
- Chunk ID: ${c.id}
  Document Title: ${c.documentTitle}
  Section: ${c.sectionTitle}
  Category: ${c.category}
  Content: "${c.content}"
''';
    }).join('\n');

    final systemInstruction = '''
You are the HODS AI Semantic Ranking Engine.
Your job is to evaluate the relevance of candidate knowledge chunks against a specific user query and retrieval goal.
You must NOT write a conversational response. Your output must strictly be a single JSON object conforming to the response schema.

Target Retrieval Goal:
- Query: "$queryText"
- Reason for Retrieval: "$retrievalReason"

Candidate Knowledge Chunks to Evaluate:
$candidatesText

Instructions:
1. For every Candidate Chunk ID, evaluate its relevance to answering the target query.
2. Provide a relevanceScore (0.0 to 1.0) where 1.0 means the chunk directly answers the query or contains crucial rules/policies required.
3. Provide a confidence rating (0.0 to 1.0).
4. Provide a short reasoning explaining your score (e.g. "Directly states refund constraints for daily stays" or "Irrelevant guide on complaint tickets").
''';

    final evaluationsSchema = Schema.object(
      properties: {
        'evaluations': Schema.array(
          description: 'Relevance evaluations for each candidate chunk',
          items: Schema.object(
            properties: {
              'chunkId': Schema.string(description: 'The unique ID of the evaluated chunk'),
              'relevanceScore': Schema.number(description: 'Relevance rating between 0.0 and 1.0'),
              'confidence': Schema.number(description: 'Confidence rating of the scorer (0.0 to 1.0)'),
              'reasoning': Schema.string(description: 'Short reasoning explaining the relevance or lack thereof'),
            },
            requiredProperties: ['chunkId', 'relevanceScore', 'confidence', 'reasoning'],
          ),
        ),
      },
      requiredProperties: ['evaluations'],
    );

    try {
      final response = await _model.generateContent(
        [Content.text(systemInstruction)],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: evaluationsSchema,
        ),
      );

      final text = response.text?.trim() ?? '';
      var cleanText = text;
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll('```json', '').replaceAll('```', '').trim();
      }

      final parsed = json.decode(cleanText) as Map<String, dynamic>;
      final evaluationsList = parsed['evaluations'] as List?;
      if (evaluationsList == null) return [];

      final results = <RetrievalResult>[];
      for (final evalMap in evaluationsList) {
        final eval = Map<String, dynamic>.from(evalMap);
        final chunkId = eval['chunkId']?.toString();
        final relevanceScore = (eval['relevanceScore'] ?? 0.0).toDouble();
        final confidence = (eval['confidence'] ?? 0.0).toDouble();
        final reasoning = eval['reasoning']?.toString() ?? '';

        final matchingChunk = candidates.firstWhere(
          (c) => c.id == chunkId,
          orElse: () => KnowledgeChunk(
            id: '',
            documentId: '',
            documentTitle: '',
            sectionTitle: '',
            category: '',
            content: '',
            tags: [],
            keywords: [],
            importanceScore: 0.0,
            metadata: {},
            lastUpdated: DateTime.now(),
          ),
        );

        if (matchingChunk.id.isNotEmpty && confidence >= config.minimumConfidence) {
          results.add(RetrievalResult(
            chunk: matchingChunk,
            relevanceScore: relevanceScore,
            retrievalConfidence: confidence,
            source: 'Firestore',
            retrievalReason: reasoning,
          ));
        }
      }

      // Sort by relevance score descending
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
      return results.take(config.maxReturnedChunks).toList();
    } catch (_) {
      // Fallback: If LLM call fails, return first maxReturnedChunks with flat scores
      return candidates.take(config.maxReturnedChunks).map((c) {
        return RetrievalResult(
          chunk: c,
          relevanceScore: 0.5,
          retrievalConfidence: 0.5,
          source: 'Firestore',
          retrievalReason: 'Fallback evaluation (ranking network error)',
        );
      }).toList();
    }
  }
}

import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_types.dart';
import 'knowledge_retriever.dart';
import 'firestore_knowledge_retriever.dart';
import 'knowledge_ranking_engine.dart';

class KnowledgeManager {
  final KnowledgeRetriever _retriever;
  final KnowledgeRankingEngine _rankingEngine;

  KnowledgeManager(GenerativeModel model, {KnowledgeRetriever? retriever})
      : _retriever = retriever ?? FirestoreKnowledgeRetriever(),
        _rankingEngine = KnowledgeRankingEngine(model);

  Future<KnowledgeContext> retrieve(
    String queryText,
    String retrievalReason, {
    KnowledgeRetrievalConfig? config,
  }) async {
    final activeConfig = config ?? KnowledgeRetrievalConfig();

    // 1. Stage 1: Candidate Retrieval
    final candidates = await _retriever.retrieve(queryText, activeConfig);

    if (candidates.isEmpty) {
      return KnowledgeContext(
        retrievedChunks: [],
        retrievalConfidence: 0.0,
        retrievalReason: 'No candidates found in database.',
        knowledgeGaps: [queryText],
        citations: [],
        sourceMetadata: {},
      );
    }

    // 2. Stage 2: LLM Semantic Evaluation
    final ranked = await _rankingEngine.rank(
      candidates,
      queryText,
      retrievalReason,
      activeConfig,
    );

    if (ranked.isEmpty) {
      return KnowledgeContext(
        retrievedChunks: [],
        retrievalConfidence: 0.0,
        retrievalReason: 'Candidates found, but none met the relevance/confidence filters.',
        knowledgeGaps: [queryText],
        citations: [],
        sourceMetadata: {'candidatesCount': candidates.length},
      );
    }

    final avgConfidence = ranked.map((r) => r.retrievalConfidence).reduce((a, b) => a + b) / ranked.length;
    final citationsList = ranked.map((r) => '${r.chunk.documentTitle} - ${r.chunk.sectionTitle}').toList();

    return KnowledgeContext(
      retrievedChunks: ranked,
      retrievalConfidence: avgConfidence,
      retrievalReason: 'Successfully retrieved and ranked ${ranked.length} semantically relevant chunks.',
      knowledgeGaps: [],
      citations: citationsList,
      sourceMetadata: {
        'totalCandidatesMatched': candidates.length,
        'configMaxReturned': activeConfig.maxReturnedChunks,
      },
    );
  }
}

import 'ai_types.dart';

abstract class KnowledgeRetriever {
  Future<List<KnowledgeChunk>> retrieve(
    String queryText,
    KnowledgeRetrievalConfig config,
  );
}

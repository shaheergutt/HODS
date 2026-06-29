import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_types.dart';
import 'knowledge_retriever.dart';

class FirestoreKnowledgeRetriever implements KnowledgeRetriever {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<List<KnowledgeChunk>> retrieve(
    String queryText,
    KnowledgeRetrievalConfig config,
  ) async {
    try {
      final snap = await _db.collection('knowledge').limit(config.maxCandidateChunks).get();

      final chunks = snap.docs.map((doc) {
        return KnowledgeChunk.fromMap(doc.data(), doc.id);
      }).toList();

      if (config.categoryFilters.isNotEmpty) {
        return chunks.where((c) => config.categoryFilters.contains(c.category)).toList();
      }

      return chunks;
    } catch (_) {
      return [];
    }
  }
}

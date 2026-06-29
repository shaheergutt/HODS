import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_types.dart';
import 'memory_retriever.dart';

class RecentConversationRetriever implements MemoryRetriever {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<MemoryContext> retrieve(String userId, MemoryRetrievalConfig config) async {
    if (!config.includeConversationSummaries) {
      return MemoryContext(conversationSummaries: []);
    }

    try {
      final snap = await _db
          .collection('users')
          .doc(userId)
          .collection('memory')
          .doc('data')
          .collection('conversation_summaries')
          .orderBy('timestamp', descending: true)
          .limit(config.maxConversationCount)
          .get();

      final summaries = snap.docs.map((doc) {
        return ConversationMemory.fromMap(doc.data(), doc.id);
      }).toList();

      return MemoryContext(conversationSummaries: summaries);
    } catch (_) {
      return MemoryContext(conversationSummaries: []);
    }
  }
}

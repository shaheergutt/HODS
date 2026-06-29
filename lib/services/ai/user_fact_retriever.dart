import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_types.dart';
import 'memory_retriever.dart';

class UserFactRetriever implements MemoryRetriever {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<MemoryContext> retrieve(String userId, MemoryRetrievalConfig config) async {
    if (!config.includeFacts) {
      return MemoryContext(userFacts: []);
    }

    try {
      final snap = await _db
          .collection('users')
          .doc(userId)
          .collection('memory')
          .doc('data')
          .collection('facts')
          .get();

      final list = snap.docs.map((doc) => UserFact.fromMap(doc.data(), doc.id)).toList();
      return MemoryContext(userFacts: list);
    } catch (_) {
      return MemoryContext(userFacts: []);
    }
  }
}

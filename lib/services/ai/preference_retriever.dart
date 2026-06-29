import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_types.dart';
import 'memory_retriever.dart';

class PreferenceRetriever implements MemoryRetriever {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<MemoryContext> retrieve(String userId, MemoryRetrievalConfig config) async {
    if (!config.includePreferences) {
      return MemoryContext(preferences: []);
    }

    try {
      final snap = await _db
          .collection('users')
          .doc(userId)
          .collection('memory')
          .doc('data')
          .collection('preferences')
          .get();

      final list = snap.docs
          .map((doc) => Preference.fromMap(doc.data(), doc.id))
          .where((p) => p.confidence >= config.minimumConfidence)
          .toList();

      return MemoryContext(preferences: list);
    } catch (_) {
      return MemoryContext(preferences: []);
    }
  }
}

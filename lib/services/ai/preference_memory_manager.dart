import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_types.dart';

class PreferenceMemoryManager {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> updatePreferences(
    String userId,
    Map<String, dynamic> newPrefs,
    String source,
  ) async {
    if (newPrefs.isEmpty) return;

    final prefCol = _db
        .collection('users')
        .doc(userId)
        .collection('memory')
        .doc('data')
        .collection('preferences');

    for (final entry in newPrefs.entries) {
      final key = entry.key;
      final newValue = entry.value;
      if (newValue == null) continue;

      final docRef = prefCol.doc(key);
      final docSnap = await docRef.get();

      double confidence = 0.3;
      if (docSnap.exists) {
        final currentData = docSnap.data()!;
        final currentValue = currentData['value'];
        final currentConfidence = (currentData['confidence'] ?? 0.0).toDouble();

        if (currentValue.toString() == newValue.toString()) {
          confidence = (currentConfidence + 0.3).clamp(0.0, 1.0);
        } else {
          confidence = 0.3;
        }
      }

      final pref = Preference(
        key: key,
        value: newValue,
        confidence: confidence,
        source: source,
        lastUpdated: DateTime.now(),
        schemaVersion: 1,
      );

      await docRef.set(pref.toMap());
    }
  }
}

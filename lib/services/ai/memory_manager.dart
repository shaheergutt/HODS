import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_types.dart';
import 'recent_conversation_retriever.dart';
import 'preference_retriever.dart';
import 'user_fact_retriever.dart';
import 'preference_memory_manager.dart';

class MemoryManager {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final RecentConversationRetriever _recentConvRetriever = RecentConversationRetriever();
  final PreferenceRetriever _prefRetriever = PreferenceRetriever();
  final UserFactRetriever _factRetriever = UserFactRetriever();
  final PreferenceMemoryManager _prefMemoryManager = PreferenceMemoryManager();

  Future<MemoryContext> retrieveMemoryContext(
    String userId,
    MemoryRetrievalConfig config,
  ) async {
    final summariesContext = await _recentConvRetriever.retrieve(userId, config);
    final preferencesContext = await _prefRetriever.retrieve(userId, config);
    final factsContext = await _factRetriever.retrieve(userId, config);

    return MemoryContext(
      conversationSummaries: summariesContext.conversationSummaries,
      preferences: preferencesContext.preferences,
      userFacts: factsContext.userFacts,
    );
  }

  Future<void> saveMemoryUpdate(
    String userId,
    MemoryUpdate update,
    String source,
  ) async {
    // 1. Save Conversation Summary
    if (update.conversationSummary.isNotEmpty && !update.conversationSummary.startsWith('Summarization failed')) {
      final summaryId = _db
          .collection('users')
          .doc(userId)
          .collection('memory')
          .doc('data')
          .collection('conversation_summaries')
          .doc()
          .id;

      final convMemory = ConversationMemory(
        id: summaryId,
        summary: update.conversationSummary,
        userIntent: update.userIntent,
        importantFacts: update.extractedFacts.entries.map((e) => '${e.key}: ${e.value}').toList(),
        completedGoals: update.completedGoals,
        unresolvedGoals: update.unresolvedGoals,
        timestamp: DateTime.now(),
        importanceScore: update.extractedFacts.containsKey('currentBookingId') ? 0.95 : 0.2,
        source: source,
        schemaVersion: 1,
      );

      await _db
          .collection('users')
          .doc(userId)
          .collection('memory')
          .doc('data')
          .collection('conversation_summaries')
          .doc(summaryId)
          .set(convMemory.toMap());
    }

    // 2. Save/Update Preferences (via PreferenceMemoryManager)
    await _prefMemoryManager.updatePreferences(userId, update.updatedPreferences, source);

    // 3. Save/Update Facts
    if (update.extractedFacts.isNotEmpty) {
      final factsCol = _db
          .collection('users')
          .doc(userId)
          .collection('memory')
          .doc('data')
          .collection('facts');

      for (final entry in update.extractedFacts.entries) {
        final key = entry.key;
        final val = entry.value;
        if (val.isEmpty) continue;

        final userFact = UserFact(
          key: key,
          value: val,
          source: source,
          timestamp: DateTime.now(),
          importanceScore: key == 'currentBookingId' ? 0.95 : 0.5,
          schemaVersion: 1,
        );

        await factsCol.doc(key).set(userFact.toMap());
      }
    }
  }

  WorkingMemory mergeToWorkingMemory(MemoryContext memContext, WorkingMemory currentWorkingMemory) {
    final Map<String, dynamic> mergedFacts = Map<String, dynamic>.from(currentWorkingMemory.facts);

    // Merge preferences
    final Map<String, Map<String, dynamic>> prefMap = {};
    for (final p in memContext.preferences) {
      prefMap[p.key] = {
        'value': p.value,
        'confidence': p.confidence,
      };
    }
    if (prefMap.isNotEmpty) {
      mergedFacts['preferences'] = prefMap;
    }

    // Merge facts
    final Map<String, String> factMap = {};
    for (final f in memContext.userFacts) {
      factMap[f.key] = f.value;
    }
    if (factMap.isNotEmpty) {
      mergedFacts['facts'] = factMap;
    }

    // Merge summaries
    final List<Map<String, dynamic>> summaryList = memContext.conversationSummaries.map((s) {
      return {
        'summary': s.summary,
        'userIntent': s.userIntent,
        'importantFacts': s.importantFacts,
        'timestamp': s.timestamp.toIso8601String(),
      };
    }).toList();
    if (summaryList.isNotEmpty) {
      mergedFacts['pastConversations'] = summaryList;
    }

    return WorkingMemory(mergedFacts);
  }
}

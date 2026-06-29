import 'ai_types.dart';

abstract class MemoryRetriever {
  Future<MemoryContext> retrieve(String userId, MemoryRetrievalConfig config);
}

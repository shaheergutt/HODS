import '../tool_interface.dart';
import '../ai_types.dart';
import '../knowledge_retriever.dart';
import '../firestore_knowledge_retriever.dart';
import '../../../models/user_model.dart';

class KnowledgeTool implements BaseTool {
  final KnowledgeRetriever _retriever = FirestoreKnowledgeRetriever();

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    String userId,
    UserRole role,
  ) async {
    final startTime = DateTime.now();
    final toolName = arguments['toolName']?.toString() ?? 'searchKnowledge';
    try {
      final query = arguments['query']?.toString() ?? '';
      final chunks = await _retriever.retrieve(query, KnowledgeRetrievalConfig());
      final docs = chunks.map((c) => c.toMap()).toList();
      final elapsed = DateTime.now().difference(startTime);
      return ToolResult(
        toolName: toolName,
        success: true,
        data: {'documents': docs},
        executionTime: elapsed,
        metadata: {'query': query, 'documentsCount': docs.length},
      );
    } catch (e) {
      final elapsed = DateTime.now().difference(startTime);
      return ToolResult(
        toolName: toolName,
        success: false,
        data: {},
        error: e.toString(),
        executionTime: elapsed,
        metadata: {},
      );
    }
  }
}

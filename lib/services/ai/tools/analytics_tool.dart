import '../tool_interface.dart';
import '../ai_types.dart';
import '../firestore_context_service.dart';
import '../../../models/user_model.dart';

class AnalyticsTool implements BaseTool {
  final FirestoreContextService _contextService = FirestoreContextService();

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    String userId,
    UserRole role,
  ) async {
    final startTime = DateTime.now();
    final toolName = arguments['toolName']?.toString() ?? 'ownerAnalytics';
    try {
      if (toolName == 'adminAnalytics') {
        final stats = await _contextService.getPlatformStats(role);
        if (stats == null) {
          throw Exception('Unauthorized access to admin platform statistics.');
        }
        final elapsed = DateTime.now().difference(startTime);
        return ToolResult(
          toolName: toolName,
          success: true,
          data: stats,
          executionTime: elapsed,
          metadata: {},
        );
      }

      // Default ownerAnalytics
      final stats = await _contextService.getOwnerBusinessStats(userId, role);
      if (stats == null) {
        throw Exception('Unauthorized access to owner business statistics.');
      }
      final elapsed = DateTime.now().difference(startTime);
      return ToolResult(
        toolName: toolName,
        success: true,
        data: stats,
        executionTime: elapsed,
        metadata: {},
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

import '../../models/user_model.dart';
import 'ai_types.dart';

abstract class BaseTool {
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    String userId,
    UserRole role,
  );
}

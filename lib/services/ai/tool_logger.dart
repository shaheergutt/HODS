import '../../models/user_model.dart';
import 'ai_types.dart';

class ToolLogger {
  static void log(
    String toolName,
    UserRole role,
    Map<String, dynamic> arguments,
    ToolResult result,
  ) {
    final timestamp = DateTime.now().toIso8601String();
    print('''
--------------------------------------------------
🔧 [HODS Tool Execution Diagnostic Log]
- Timestamp: $timestamp
- Tool Name: $toolName
- User Role: ${role.name.toUpperCase()}
- Arguments: $arguments
- Success: ${result.success}
- Execution Time: ${result.executionTime.inMilliseconds} ms
- Error: ${result.error ?? 'None'}
--------------------------------------------------
''');
  }

  static void logValidationError(
    String toolName,
    UserRole role,
    Map<String, dynamic> arguments,
    String validationError,
  ) {
    final timestamp = DateTime.now().toIso8601String();
    print('''
--------------------------------------------------
⚠️ [HODS Tool Validation Error Log]
- Timestamp: $timestamp
- Tool Name: $toolName
- User Role: ${role.name.toUpperCase()}
- Arguments: $arguments
- Validation Error: $validationError
--------------------------------------------------
''');
  }
}

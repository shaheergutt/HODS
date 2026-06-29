import '../../models/user_model.dart';
import 'tool_registry.dart';

class ToolValidator {
  static Map<String, dynamic> validate(
    String toolName,
    Map<String, dynamic> arguments,
    UserRole role,
  ) {
    final definition = ToolRegistry.getByName(toolName);
    if (definition == null) {
      return {
        'isValid': false,
        'error': 'Tool "$toolName" does not exist in the registry.'
      };
    }

    if (!definition.allowedRoles.contains(role)) {
      return {
        'isValid': false,
        'error': 'User role ${role.name.toUpperCase()} is unauthorized to invoke tool "$toolName".'
      };
    }

    final expectedParams = definition.parameterSchema;
    for (final entry in expectedParams.entries) {
      final paramName = entry.key;
      final schemaInfo = entry.value as Map<String, dynamic>;
      
      if (arguments.containsKey(paramName) && arguments[paramName] != null) {
        final val = arguments[paramName];
        final expectedType = schemaInfo['type']?.toString();
        
        if (expectedType == 'number' && val is! num) {
          return {
            'isValid': false,
            'error': 'Parameter "$paramName" expects a number, but got "${val.runtimeType}".'
          };
        }
        if (expectedType == 'string' && val is! String) {
          return {
            'isValid': false,
            'error': 'Parameter "$paramName" expects a string, but got "${val.runtimeType}".'
          };
        }
        if (expectedType == 'array' && val is! List) {
          return {
            'isValid': false,
            'error': 'Parameter "$paramName" expects an array, but got "${val.runtimeType}".'
          };
        }
      }
    }

    return {'isValid': true, 'error': null};
  }
}

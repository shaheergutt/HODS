import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../models/user_model.dart';
import 'ai_types.dart';
import 'tool_registry.dart';

class ToolCallingAgent {
  final GenerativeModel _model;

  ToolCallingAgent(this._model);

  GenerativeModel get model => _model;

  Future<ToolCall> selectTool(
    String userMessage,
    UserRole role, {
    String? plannerReasoning,
    Map<String, dynamic>? workingMemory,
  }) async {
    final tools = ToolRegistry.getRegisteredTools();
    
    final toolDefsString = tools.map((t) {
      return '''
- Name: ${t.name}
  Category: ${t.category}
  Description: ${t.description}
  Parameters Schema: ${json.encode(t.parameterSchema)}
  Allowed Roles: ${t.allowedRoles.map((r) => r.name.toUpperCase()).join(', ')}
''';
    }).join('\n');

    final plannerContext = plannerReasoning != null ? '''
Current Planner Goal & Intent: "$plannerReasoning"
Facts in Working Memory: ${json.encode(workingMemory ?? {})}
Please extract parameters matching this intent, utilizing the facts in working memory if they provide details missing from the direct message.
''' : '';

    final systemInstruction = '''
You are the HODS Tool Selection Agent.
Analyze the user's current request and decide which registered tool should be invoked to satisfy the request.

User Role: ${role.name.toUpperCase()}
$plannerContext

Available HODS Tools:
$toolDefsString

Instructions:
1. Identify the single best tool that fits the user's intent.
2. If the query is a general conversation, greeting, FAQ question, or if no tool fits, select the toolName as "general_inquiry" with an empty arguments object.
3. Validate parameters against the schema. If parameters are present in the user request, extract them into the arguments object.
4. If a tool has a restricted list of allowed roles and the User Role is not in that list, select the tool honestly. The validation layer will handle enforcement.

Output MUST be a single raw JSON object matching the requested schema.
''';

    final contents = [Content.text("$systemInstruction\n\nUser Message: \"$userMessage\"")];
    
    try {
      final response = await _model.generateContent(
        contents,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(
            properties: {
              'toolName': Schema.string(description: 'Selected tool name or "general_inquiry"'),
              'arguments': Schema.object(
                description: 'Arguments matching the tool\'s parameter schema',
                properties: {
                  'city': Schema.string(description: 'Name of the city to search in'),
                  'budget': Schema.number(description: 'Maximum budget in PKR'),
                  'university': Schema.string(description: 'Hostels near this university'),
                  'roomType': Schema.string(description: 'Room type preference (single or shared)'),
                  'stayType': Schema.string(description: 'Stay duration mode (daily or monthly)'),
                  'hostelIds': Schema.array(
                    description: 'List of hostel document IDs',
                    items: Schema.string(),
                  ),
                  'latitude': Schema.number(description: 'GPS latitude coordinate'),
                  'longitude': Schema.number(description: 'GPS longitude coordinate'),
                  'hostelId': Schema.string(description: 'The target hostel ID'),
                  'hostelName': Schema.string(description: 'Name of the hostel'),
                  'roomNumber': Schema.string(description: 'Room number'),
                  'bedsBooked': Schema.number(description: 'Number of beds to book'),
                  'totalAmount': Schema.number(description: 'Price amount in PKR'),
                  'checkInDate': Schema.string(description: 'Check-in date string'),
                  'checkOutDate': Schema.string(description: 'Check-out date string'),
                  'bookingId': Schema.string(description: 'ID of the booking'),
                  'title': Schema.string(description: 'Complaint summary title'),
                  'category': Schema.string(description: 'Category of issue (e.g. Internet, Mess, Water)'),
                  'description': Schema.string(description: 'Detailed issue text'),
                  'complaintId': Schema.string(description: 'ID of complaint document'),
                  'status': Schema.string(description: 'New status (resolved, closed, in-progress)'),
                  'query': Schema.string(description: 'Search query terms'),
                },
              ),
              'confidence': Schema.number(description: 'Confidence rating (0.0 to 1.0)'),
              'reasoning': Schema.string(description: 'Short details explaining choice'),
            },
            requiredProperties: ['toolName', 'arguments', 'confidence', 'reasoning'],
          ),
        )
      );

      final text = response.text?.trim() ?? '';
      var cleanText = text;
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll('```json', '').replaceAll('```', '').trim();
      }

      final parsed = json.decode(cleanText) as Map<String, dynamic>;
      return ToolCall.fromMap(parsed);
    } catch (e) {
      return ToolCall(
        toolName: 'general_inquiry',
        arguments: {},
        confidence: 0.1,
        reasoning: 'Exception during tool selection: $e',
      );
    }
  }
}

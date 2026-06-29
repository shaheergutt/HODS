import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_types.dart';

class MemorySummarizer {
  final GenerativeModel _model;

  MemorySummarizer(this._model);

  Future<MemoryUpdate> summarize(
    String userMessage,
    ExecutionState executionState,
  ) async {
    final stepsString = executionState.steps.isEmpty ? 'None' : executionState.steps.asMap().entries.map((e) {
      final idx = e.key + 1;
      final step = e.value;
      return '''
Step $idx:
- Goal: ${step.plannerReasoning}
- Tool: ${step.toolCall.toolName} with arguments: ${json.encode(step.toolCall.arguments)}
- Success: ${step.toolResult?.success ?? false}
- Output Data: ${json.encode(step.toolResult?.data ?? {})}
  Error: ${step.toolResult?.error ?? 'None'}
- Observation: ${step.observation ?? 'None'}
''';
    }).join('\n');

    final systemInstruction = '''
You are the HODS AI Memory Summarizer.
Your job is to analyze the completed conversation exchange and extract a concise summary, the user's core intent, persistent facts, and any preference updates.
You must NOT output any conversational text. Your output must strictly be a single JSON object conforming to the response schema.

User Request: "$userMessage"
Completed Reasoning Loop Steps:
$stepsString

Instructions:
1. "conversationSummary": Write a concise, 1-2 sentence summary of what was asked and what was found or done. E.g. "User requested hostel search near FAST under 25000 budget and checked active bookings."
2. "userIntent": Extract the primary core intent (e.g. "search_hostels", "lookup_booking", "file_complaint", "roommate_matching").
3. "extractedFacts": Extract key factual information that should persist (e.g. "currentBookingId", "currentComplaintId", "favoriteHostel"). Only include facts explicitly confirmed or returned in tool outputs. E.g., if a booking was created, record {"currentBookingId": "XYZ"}.
4. "updatedPreferences": Extract user preferences stated or implied in the request or parameters (e.g. "budget": 18000, "roomType": "single", "university": "FAST", "stayDuration": "monthly", "acRequirement": "ac"). Do not guess; only extract values explicitly mentioned or executed.
5. "completedGoals": List descriptions of goals completed.
6. "unresolvedGoals": List descriptions of goals that were not fully satisfied or are still pending.
''';

    final memoryUpdateSchema = Schema.object(
      properties: {
        'conversationSummary': Schema.string(description: 'Concise summary of the conversation'),
        'userIntent': Schema.string(description: 'Primary intent of the user'),
        'extractedFacts': Schema.object(
          description: 'Persistent facts discovered during reasoning (e.g. {"currentBookingId": "XYZ"})',
          properties: {
            'currentBookingId': Schema.string(description: 'Current booking document ID'),
            'currentComplaintId': Schema.string(description: 'Current complaint ID'),
            'favoriteHostel': Schema.string(description: 'Favorite hostel name or ID'),
            'currentReservation': Schema.string(description: 'Details of current reservation'),
            'paymentPreference': Schema.string(description: 'Preferred payment method'),
          }
        ),
        'updatedPreferences': Schema.object(
          description: 'Updated user preferences identified (e.g. {"budget": 18000, "roomType": "single"})',
          properties: {
            'budget': Schema.number(description: 'Monthly budget limit in PKR'),
            'university': Schema.string(description: 'Preferred university location proximity'),
            'roomType': Schema.string(description: 'Preferred room type (single or shared)'),
            'stayDuration': Schema.string(description: 'Stay duration preference (daily or monthly)'),
            'acRequirement': Schema.string(description: 'AC requirement (ac or non-ac)'),
            'wifiRequirement': Schema.string(description: 'WiFi requirement'),
            'mealPreference': Schema.string(description: 'Meals preference'),
            'genderPreference': Schema.string(description: 'Gender preference'),
            'preferredHostel': Schema.string(description: 'Specific hostel preference'),
          }
        ),
        'completedGoals': Schema.array(description: 'Completed goal descriptions list', items: Schema.string()),
        'unresolvedGoals': Schema.array(description: 'Goals remaining/outstanding at loop exit', items: Schema.string()),
      },
      requiredProperties: [
        'conversationSummary',
        'userIntent',
        'extractedFacts',
        'updatedPreferences',
        'completedGoals',
        'unresolvedGoals'
      ]
    );

    try {
      final response = await _model.generateContent(
        [Content.text(systemInstruction)],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: memoryUpdateSchema,
        ),
      );

      final text = response.text?.trim() ?? '';
      var cleanText = text;
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll('```json', '').replaceAll('```', '').trim();
      }
      final parsed = json.decode(cleanText) as Map<String, dynamic>;
      return MemoryUpdate.fromMap(parsed);
    } catch (e) {
      return MemoryUpdate(
        conversationSummary: 'Summarization failed: $e',
        userIntent: 'unknown',
        extractedFacts: {},
        updatedPreferences: {},
        completedGoals: [],
        unresolvedGoals: [],
      );
    }
  }
}

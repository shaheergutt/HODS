import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../models/user_model.dart';
import '../ai_types.dart';

class ResponseGenerator {
  final GenerativeModel _model;

  ResponseGenerator(this._model);

  Future<String> generate(
    String originalMessage,
    UserRole role,
    String conversationSummary,
    ExecutionState executionState,
    MemoryContext memoryContext,
    KnowledgeContext knowledgeContext,
    RecommendationContext recommendationContext, {
    ReflectionResult? reflectionResult,
  }) async {
    final stepsString = executionState.steps.isEmpty ? 'None' : executionState.steps.asMap().entries.map((e) {
      final idx = e.key + 1;
      final step = e.value;
      return '''
Step $idx:
- Goal Reasoning: ${step.plannerReasoning}
- Tool Executed: ${step.toolCall.toolName} with arguments: ${json.encode(step.toolCall.arguments)}
- Execution Success: ${step.toolResult?.success ?? false}
- Result Data: ${json.encode(step.toolResult?.data ?? {})}
  Error: ${step.toolResult?.error ?? 'None'}
- Observation made: ${step.observation ?? 'None'}
''';
    }).join('\n');

    final preferencesString = memoryContext.preferences.isEmpty 
        ? 'None' 
        : memoryContext.preferences.map((p) => '${p.key}: ${p.value} (Confidence: ${p.confidence.toStringAsFixed(2)})').join(', ');
    final factsString = memoryContext.userFacts.isEmpty 
        ? 'None' 
        : memoryContext.userFacts.map((f) => '${f.key}: ${f.value}').join(', ');
    final summariesString = memoryContext.conversationSummaries.isEmpty 
        ? 'None' 
        : memoryContext.conversationSummaries.map((s) => '- ${s.summary} (Intent: ${s.userIntent})').join('\n');

    final knowledgeString = knowledgeContext.retrievedChunks.isEmpty 
        ? 'None' 
        : knowledgeContext.retrievedChunks.map((r) => '- [Category: ${r.chunk.category}, Document: ${r.chunk.documentTitle}]: "${r.chunk.content}"').join('\n');

    final recommendationsString = recommendationContext.rankedCandidates.isEmpty
        ? 'None'
        : '''
Recommendations Generated:
- Tradeoffs Identified: ${recommendationContext.recommendationTradeoffs.join(', ')}
- Reasoning: ${recommendationContext.recommendationReasoning}
 
Ranked Hostels:
${recommendationContext.rankedCandidates.map((c) => '''
Hostel: ${c.hostelName} (Total Score: ${c.totalScore.toStringAsFixed(2)})
Strengths: ${c.strengths.join(', ')}
Weaknesses: ${c.weaknesses.join(', ')}
Raw Data: ${json.encode(c.hostelData)}
''').join('\n')}
''';

    final activeReflection = reflectionResult ?? executionState.reflectionResult;

    final reflectionString = activeReflection == null
        ? 'No final reflection was executed.'
        : '''
AI Self-Verification Metrics (ReflectionResult):
- Planner Confidence: ${activeReflection.plannerConfidence.toStringAsFixed(2)}
- Reflection Confidence: ${activeReflection.reflectionConfidence.toStringAsFixed(2)}
- Satisfied Goals: ${activeReflection.satisfiedGoals.join(', ')}
- Missing Goals: ${activeReflection.missingGoals.join(', ')}
- Violated Constraints: ${activeReflection.violatedConstraints.join(', ')}
- Contradictions: ${activeReflection.contradictions.join(', ')}
- Verification Scores: Goal (${activeReflection.verificationScore.goalScore}), Constraint (${activeReflection.verificationScore.constraintScore}), Knowledge (${activeReflection.verificationScore.knowledgeScore}), Tool Coverage (${activeReflection.verificationScore.toolCoverageScore}), Recommendation (${activeReflection.verificationScore.recommendationScore}), Memory (${activeReflection.verificationScore.memoryScore}), Overall (${activeReflection.verificationScore.overallScore})
''';

    final systemInstruction = '''
You are the HODS AI Response Generator. Your task is to write a highly friendly, professional, and conversational response to the user's message.
You must synthesize your final response from the working memory, planning history, goals achieved, long-term memory context, and retrieved domain knowledge rules.

User Role: ${role.name.toUpperCase()}
Conversation Summary: "$conversationSummary"
Execution Stop Reason: "${executionState.stopReason ?? 'GoalCompleted'}"

Long-Term Remembered User Context (MemoryContext):
- Active Learned Preferences: $preferencesString
- Stored Persistent Facts: $factsString
- Past Conversation Summaries:
$summariesString

Retrieved Domain Knowledge Context (KnowledgeContext):
$knowledgeString

Ranked Recommendations (RecommendationContext):
$recommendationsString

$reflectionString

Working Memory Facts:
${json.encode(executionState.workingMemory.toMap())}

Planner Observations:
${executionState.observations.map((o) => '- [${o.toolName}]: ${o.observation}').join('\n')}

Goals Status:
- Pending: ${executionState.goals.where((g) => g.status != 'completed').map((g) => g.description).join(', ')}
- Completed: ${executionState.goals.where((g) => g.status == 'completed').map((g) => '${g.description} (Reason: ${g.completionReason ?? ''})').join(', ')}

Execution Steps History:
$stepsString

Instructions:
1. Explain the results and reasoning naturally. Do not output raw JSON or internal database IDs. Conversationalize the facts in Working Memory.
2. Incorporate retrieved knowledge context and policies naturally to answer rules/guides queries (e.g. daily stays cancellation guidelines). Do not copy verbatim unless appropriate, explain in simple friendly terms.
3. Incorporate remembered context naturally (e.g. "I remember you usually search for hostels near FAST..."). Do not sound repetitive or robotic.
4. If the Stop Reason is "NeedUserClarification", do not formulate a final answer. Instead, friendly and clearly present the clarification question asked by the planner in the last step.
5. If the Stop Reason is "SafetyLimitReached", "DuplicateExecution", or "ToolFailure", politely explain that you ran into an issue or safety constraint and present the best helpful answer you can assemble from any successfully retrieved working memory facts.
6. If recommending hostels, summarize pricing, locations, and ratings in a friendly format.
7. If tracking booking or complaint status, summarize the details nicely and offer options.
8. Keep the response clean and helpful. Do not output JSON. Output ONLY the friendly conversational text response.
9. If Ranked Recommendations exist, present them beautifully. Explain why they were chosen using the Strengths/Weaknesses and Reasoning without mentioning mathematical scores. Compare the options if there are multiple.
10. Use the AI Self-Verification Metrics (if available) to confidently assure the user that their specific constraints and goals were verified, but DO NOT expose the internal reflection chain-of-thought, technical telemetry, or raw mathematical scores.
11. Never expose internal planner reasoning or chain-of-thought (e.g., how the planner decided to call tools, the internal steps, or loop iterations).
12. If the user asks why a recommendation was made or how it was verified, summarize the goals satisfied, the policies considered, the constraints verified (such as budget, roommate compatibility, or locations), and the confidence level, without revealing internal reasoning logs.
''';

    final contents = [Content.text("$systemInstruction\n\nUser Message: \"$originalMessage\"")];

    try {
      final response = await _model.generateContent(contents);
      return response.text?.trim() ?? 'I encountered an issue generating a response.';
    } catch (e) {
      return 'I had trouble connecting to my reasoning network. Stated query was: $originalMessage';
    }
  }
}

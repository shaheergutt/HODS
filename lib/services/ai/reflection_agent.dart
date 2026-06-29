import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_types.dart';
import 'reflection_evaluator.dart';

class ReflectionAgent {
  final GenerativeModel _model;

  ReflectionAgent(this._model);

  /// Performs a reflection evaluation using Gemini Structured Outputs.
  Future<ReflectionResult> reflect(
    ExecutionState state,
    ReflectionMode mode,
    ReflectionConfig config,
  ) async {
    final schema = Schema.object(
      properties: {
        'isComplete': Schema.boolean(description: 'True if reasoning is flawless and all goals are completely met. False if any issues exist.'),
        'plannerConfidence': Schema.number(description: 'Estimated confidence of the planner (0.0 to 1.0)'),
        'reflectionConfidence': Schema.number(description: 'Confidence in this reflection evaluation (0.0 to 1.0)'),
        'stopReason': Schema.string(description: 'Reason for stopping or requiring repair'),
        'satisfiedGoals': Schema.array(description: 'List of successfully completed user goals', items: Schema.string()),
        'missingGoals': Schema.array(description: 'List of goals missed or ignored by the planner', items: Schema.string()),
        'violatedConstraints': Schema.array(description: 'List of user constraints that were broken (e.g. Budget exceeded)', items: Schema.string()),
        'contradictions': Schema.array(description: 'List of contradictions found between reasoning, tools, and knowledge', items: Schema.string()),
        'issues': Schema.array(
          description: 'Detailed list of critical reasoning flaws',
          items: Schema.object(
            properties: {
              'issueType': Schema.string(description: 'E.g., MissingGoal, MissingConstraint, KnowledgeConflict, RecommendationConflict, MissingToolExecution, LowConfidence, MissingKnowledge, ClarificationRequired'),
              'severity': Schema.string(description: 'low, medium, high, or critical'),
              'description': Schema.string(description: 'What went wrong'),
              'affectedGoal': Schema.string(description: 'Which goal is blocked'),
              'suggestedFix': Schema.string(description: 'How the planner can auto-repair this issue'),
              'toolHint': Schema.string(description: 'Suggested tool name to execute, if action is executeTool (e.g. searchHostels, createBooking)'),
              'knowledgeQuery': Schema.string(description: 'Suggested search query, if action is retrieveKnowledge (e.g. daily stay refund policy)'),
              'plannerGoal': Schema.string(description: 'Suggested goal to add to planner, if action is continuePlanning (e.g. verify room constraints)'),
            },
            requiredProperties: ['issueType', 'severity', 'description', 'suggestedFix'],
          ),
        ),
      },
      requiredProperties: [
        'isComplete',
        'plannerConfidence',
        'reflectionConfidence',
        'satisfiedGoals',
        'missingGoals',
        'violatedConstraints',
        'contradictions',
        'issues',
      ],
    );

    final memoryContextData = state.memoryContext != null
        ? {
            'preferences': state.memoryContext!.preferences.map((p) => p.toMap()).toList(),
            'userFacts': state.memoryContext!.userFacts.map((f) => f.toMap()).toList(),
            'conversationSummaries': state.memoryContext!.conversationSummaries.map((s) => s.toMap()).toList(),
          }
        : state.recommendationContext.toMap(); // fallback proxy

    final String prompt = '''
You are the HODS AI Enterprise Reflection Agent.
Your ONLY job is to evaluate the Planner's reasoning, tool executions, and state. 
You NEVER generate conversational responses for the user.
You evaluate the state and output a highly structured JSON evaluation.

Reflection Mode: ${mode.name.toUpperCase()}

Configuration Directives:
- Verify Knowledge Consistency: ${config.verifyKnowledgeConsistency}
- Verify Tool Coverage: ${config.verifyToolCoverage}
- Verify Recommendations: ${config.verifyRecommendations}
- Verify Constraints: ${config.verifyConstraints}
- Verify Memory Context: ${config.verifyMemory}

Execution State Details:
------------------------
1. Original Request: "${state.originalRequest}"
2. Working Memory Facts: ${json.encode(state.workingMemory.toMap())}
3. Memory Context (Long Term): ${json.encode(memoryContextData)}
4. Tool Execution History: ${json.encode(state.toolExecutionHistory.map((t) => {'tool': t.toolName, 'success': t.success, 'error': t.error, 'data': t.data}).toList())}
5. Planner Observations: ${json.encode(state.observations.map((o) => o.toMap()).toList())}
6. Knowledge Context (retrieved chunks): ${json.encode(state.knowledgeContext.toMap())}
7. Recommendation Context: ${json.encode(state.recommendationContext.toMap())}

Rules & Verification Instructions:
1. Goal Verification (Verify HODS goals):
   Check if the Planner's current state and goals have completely resolved what the user originally requested.
   List satisfied goals in 'satisfiedGoals', and any missing or unresolved goals in 'missingGoals'.

2. Constraint Verification (Verify budget, gender, distance, university, room type, amenities, booking duration):
   If there were budget requirements (e.g. max PKR 25000), gender preferences (e.g. female-only hostel), distance constraints, target universities (e.g. near FAST NUCES), specific room types (e.g. single room), room amenities, or booking duration constraints in the request or memory context:
   Cross-reference them with the properties of the hostels found. If any constraint is violated, add it to 'violatedConstraints' and add an issue with type 'MissingConstraint' or 'RecommendationConflict' and appropriate severity (medium or high).

3. Tool Verification (Verify executed tools):
   Verify if the planner executed the necessary tools.
   For example, if the user requested roommate matches, was the 'findRoommates' tool executed? If the user asked to search hostels, was 'searchHostels' or 'searchNearbyHostels' executed? If the user asked to book, was 'createBooking' executed?
   If a necessary tool was NOT executed, add an issue of type 'MissingToolExecution' (severity high/critical), and provide a 'toolHint' with the exact name of the tool to run.

4. Knowledge Verification (Verify retrieved policy chunks and RAG guidelines):
   Verify if retrieved knowledge chunks (e.g., cancellation refund rules or CNIC check-in requirements) contradict the planner's claims or final answers. 
   If policies were not retrieved but are critical (e.g. refund rules for daily stays or check-in CNIC guidelines), or if the planner contradicts retrieved rules, add an issue of type 'MissingKnowledge' or 'KnowledgeConflict' (severity high), and provide a 'knowledgeQuery' for the knowledge base (e.g. 'daily stay refund policy').

5. Recommendation Verification:
   If the planner generated recommendations (recommendationContext contains candidates), verify if the recommendations match user preferences and constraints. If the hostel price exceeds budget, or if rating/amenities do not align with memory preferences, add a 'RecommendationConflict' issue.

6. Memory Verification:
   Verify if the planner integrated persistent facts and active learned preferences from the Memory Context (preferences and userFacts). If they are ignored, log a 'MemoryConflict' or 'MissingConstraint' issue.

7. Safety Verification (Prevent loops, repetitions, low confidence):
   Verify that the planner does not repeat the same reasoning or call tools with duplicate arguments.
   If plannerConfidence is low (< config.minimumConfidence) or reflectionConfidence is low, raise 'LowConfidence' issue (severity medium).

8. Guided Auto-Repair Planning Loop:
   Reflection must guide the planner using issue hints:
   - For MissingToolExecution: set 'toolHint' to the exact name of the tool (e.g., searchHostels, compareHostels, getHostelDetails, getBookings, createBooking, cancelBooking, trackBooking, getComplaints, createComplaint, findRoommates, ownerAnalytics, adminAnalytics, searchKnowledge, searchPolicies).
   - For MissingKnowledge / KnowledgeConflict: set 'knowledgeQuery' to a relevant search term.
   - For MissingConstraint: set 'plannerGoal' to the constraint verification goal.
''';

    try {
      final response = await _model.generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: schema,
        ),
      );

      final text = response.text?.trim() ?? '{}';
      var cleanText = text;
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll('```json', '').replaceAll('```', '').trim();
      }
      
      final parsed = json.decode(cleanText) as Map<String, dynamic>;
      
      // Delegate parsing and score computation to the Evaluator
      return ReflectionEvaluator.evaluate(parsed, mode, config);

    } catch (e) {
      // Fallback: If reflection crashes, we assume planner is complete to prevent hanging,
      // but log a critical issue for diagnostics.
      return ReflectionResult(
        isComplete: true,
        reflectionMode: mode,
        plannerConfidence: 0.5,
        reflectionConfidence: 0.0,
        verificationScore: VerificationScore(overallScore: 0.0),
        issues: [
          ReflectionIssue(
            issueType: 'ReflectionFailure',
            severity: ReflectionSeverity.critical,
            description: 'The reflection LLM failed to parse constraints.',
            affectedGoal: 'System Stability',
            suggestedFix: 'None. Bypassing reflection.',
          )
        ],
        stopReason: 'Reflection crashed',
      );
    }
  }
}

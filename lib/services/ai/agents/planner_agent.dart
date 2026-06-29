import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../models/user_model.dart';
import '../ai_types.dart';
import '../tool_calling_agent.dart';
import '../tool_validator.dart';
import '../tool_executor.dart';
import '../tool_logger.dart';
import '../tool_registry.dart';
import '../knowledge_manager.dart';
import '../recommendation_manager.dart';
import '../reflection_manager.dart';

class PlannerAgent {
  final ToolCallingAgent _callingAgent;
  final ToolExecutor _executor;
  late final KnowledgeManager _knowledgeManager;
  late final RecommendationManager _recommendationManager;
  late final ReflectionManager _reflectionManager;

  PlannerAgent(
    this._callingAgent, {
    KnowledgeManager? knowledgeManager,
    RecommendationManager? recommendationManager,
    ReflectionManager? reflectionManager,
    ToolExecutor? executor,
  }) : _executor = executor ?? ToolExecutor() {
    _knowledgeManager = knowledgeManager ?? KnowledgeManager(_callingAgent.model);
    _recommendationManager = recommendationManager ?? RecommendationManager(_callingAgent.model);
    _reflectionManager = reflectionManager ?? ReflectionManager(_callingAgent.model);
  }

  Future<ExecutionState> executePlan(
    String message,
    String userId,
    UserRole role, {
    WorkingMemory? initialWorkingMemory,
    MemoryContext? memoryContext,
  }) async {
    final model = _callingAgent.model;

    // Reset reflection manager for a new planning session
    _reflectionManager.reset();

    // Initialize ExecutionState
    final state = ExecutionState(
      originalRequest: message,
      role: role,
      conversationSummary: '',
      goals: [], // Starts empty, will be initialized/populated by the planner
      workingMemory: initialWorkingMemory ?? WorkingMemory(),
      observations: [],
      steps: [],
      toolExecutionHistory: [],
      knowledgeContext: KnowledgeContext(),
      memoryContext: memoryContext,
    );

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

    final planningSchema = Schema.object(
      properties: {
        'finished': Schema.boolean(description: 'Whether the planner has finished gathering all information'),
        'plannerReasoning': Schema.string(description: 'Detailed reasoning explaining next tool requirement or final plan closure'),
        'plannerConfidence': Schema.number(description: 'Confidence rating between 0.0 and 1.0'),
        'goalCompleted': Schema.boolean(description: 'True if the primary user goals have been resolved'),
        'needUserClarification': Schema.boolean(description: 'True if critical parameters are missing and we need to query the user'),
        'clarificationQuestion': Schema.string(description: 'A polite question clarifying missing constraints'),
        'remainingGoals': Schema.array(
          description: 'Goals remaining to be processed',
          items: Schema.object(
            properties: {
              'description': Schema.string(description: 'Description of the goal'),
              'status': Schema.string(description: 'Status (always "pending")'),
              'priority': Schema.string(description: 'Priority ("high", "medium", "low")'),
              'dependencies': Schema.array(description: 'Dependencies list', items: Schema.string()),
              'completionReason': Schema.string(description: 'Completion explanation if any'),
            },
            requiredProperties: ['description', 'status', 'priority'],
          ),
        ),
        'completedGoals': Schema.array(
          description: 'Goals successfully achieved',
          items: Schema.object(
            properties: {
              'description': Schema.string(description: 'Description of the goal'),
              'status': Schema.string(description: 'Status (always "completed")'),
              'priority': Schema.string(description: 'Priority'),
              'dependencies': Schema.array(description: 'Dependencies list', items: Schema.string()),
              'completionReason': Schema.string(description: 'Reason explaining completion'),
            },
            requiredProperties: ['description', 'status', 'priority', 'completionReason'],
          ),
        ),
        'stopReason': Schema.string(description: 'Why the loop is stopping if it has to terminate'),
        'newObservation': Schema.string(description: 'An observation derived from the latest tool outcome'),
        'newWorkingMemoryFacts': Schema.object(
          description: 'Facts key-values to update in working memory',
          properties: {
            'selectedHostel': Schema.string(description: 'Details or ID of target hostel'),
            'selectedBooking': Schema.string(description: 'Details or status of target booking'),
            'refundPolicy': Schema.string(description: 'Policy or guideline details found'),
            'complaintStatus': Schema.string(description: 'Status details of complaint'),
            'analyticsSummary': Schema.string(description: 'Summary of analytics findings'),
            'roommateMatch': Schema.string(description: 'Details of matching roommate profiles'),
            'hostelComparison': Schema.string(description: 'Details of hostel comparisons'),
            'latestComplaintId': Schema.string(description: 'ID of the latest complaint created/updated'),
            'latestComplaintStatus': Schema.string(description: 'Status of the latest complaint created/updated'),
            'latestComplaintPriority': Schema.string(description: 'Priority of the latest complaint created/updated'),
          },
        ),
        'nextKnowledgeGoal': Schema.object(
          description: 'A structured goal representing knowledge retrieval requirement (refund policies, rules, check-in guides, etc.) before taking action',
          properties: {
            'reason': Schema.string(description: 'Detailed explanation of why knowledge is required'),
            'query': Schema.string(description: 'Search terms to query HODS knowledge base'),
            'expectedAnswer': Schema.string(description: 'A brief description of what facts we expect to retrieve'),
            'category': Schema.string(description: 'Document category (e.g. policies, hostel_rules, owner_guides, admin_guides, faqs)'),
            'priority': Schema.string(description: 'Goal priority ("high", "medium", "low")'),
          },
          requiredProperties: ['reason', 'query', 'expectedAnswer', 'category', 'priority'],
        ),
        'nextRecommendationGoal': Schema.object(
          description: 'A goal representing a request to evaluate, score, and rank retrieved hostels based on constraints.',
          properties: {
            'objective': Schema.string(description: 'E.g., "Find the best hostel for a student with budget X"'),
            'rankingCriteria': Schema.array(description: 'Criteria to rank by', items: Schema.string()),
            'constraints': Schema.array(description: 'Hard constraints', items: Schema.string()),
            'priority': Schema.string(description: 'Priority ("high", "medium", "low")'),
            'expectedOutcome': Schema.string(description: 'E.g., "A ranked list of 3 hostels"'),
          },
          requiredProperties: ['objective', 'rankingCriteria', 'constraints', 'priority', 'expectedOutcome'],
        ),
      },
      requiredProperties: [
        'finished',
        'plannerReasoning',
        'plannerConfidence',
        'goalCompleted',
        'needUserClarification',
        'remainingGoals',
        'completedGoals'
      ],
    );

    // Iterative Reasoning Loop (up to 5 loops)
    while (state.currentIteration < 5) {
      String reflectionFeedback = '';
      if (state.reflectionResult != null && !state.reflectionResult!.isComplete) {
        final r = state.reflectionResult!;
        final issueStrings = r.issues.map((i) {
          final hints = [
            if (i.toolHint != null) 'Tool Hint: execute tool "${i.toolHint}"',
            if (i.knowledgeQuery != null) 'Knowledge Query Hint: search for "${i.knowledgeQuery}"',
            if (i.plannerGoal != null) 'Planner Goal Hint: add goal "${i.plannerGoal}"',
          ].join(', ');
          return '- [Issue: ${i.issueType}] ${i.description}. Fix: ${i.suggestedFix}${hints.isNotEmpty ? " ($hints)" : ""}';
        }).join('\n');
        reflectionFeedback = '''
### SELF-VERIFICATION & REFLECTION FEEDBACK (Previous Step Flawed):
The Enterprise Reflection Engine has analyzed the previous execution step and flagged issues. You MUST address these issues in the current reasoning iteration:
$issueStrings

Recommended next capability action: ${r.recommendedAction.name}
''';
      }

      final systemInstruction = '''
You are the HODS AI Goal-Oriented Planner.
Your job is to coordinate multi-step planning, evaluate tool execution results, manage structured goals, update working memory, and determine if additional actions are needed.
You must NOT output a conversational response to the user. Your output must strictly be a single JSON object conforming to the planning schema.

User Request: "${state.originalRequest}"
User Role: ${state.role.name.toUpperCase()}
Current Loop Iteration: ${state.currentIteration + 1} / 5

${reflectionFeedback.isNotEmpty ? reflectionFeedback : ''}

HODS System Tools Available:
$toolDefsString

Current Goals Status:
- Pending Goals: ${state.goals.isEmpty ? 'None initialized yet.' : state.goals.where((g) => g.status != 'completed').map((g) => '"${g.description}" (${g.priority} priority)').join(', ')}
- Completed Goals: ${state.goals.where((g) => g.status == 'completed').map((g) => '"${g.description}" (Reason: ${g.completionReason ?? ''})').join(', ')}

Working Memory Facts (key facts collected so far):
${json.encode(state.workingMemory.toMap())}

Knowledge Context (retrieved domain rules, policies, and FAQs):
- Retrieval Reason: ${state.knowledgeContext.retrievalReason}
- retrievedChunks:
${state.knowledgeContext.retrievedChunks.isEmpty ? 'None' : state.knowledgeContext.retrievedChunks.map((r) => '- [Document: ${r.chunk.documentTitle}, Relevance: ${r.relevanceScore.toStringAsFixed(2)}, Scorer Reason: ${r.retrievalReason}]: "${r.chunk.content}"').join('\n')}
- Citations: ${state.knowledgeContext.citations.join(', ')}
- Knowledge Gaps: ${state.knowledgeContext.knowledgeGaps.join(', ')}

Observations made so far:
${state.observations.isEmpty ? 'None' : state.observations.map((o) => '- [${o.toolName}]: ${o.observation}').join('\n')}

Tool execution steps history:
${state.steps.isEmpty ? 'None' : state.steps.asMap().entries.map((e) {
  final idx = e.key + 1;
  final step = e.value;
  return '''
Step $idx:
- Target Reasoning: ${step.plannerReasoning}
- Tool Call: ${step.toolCall.toolName} with arguments: ${json.encode(step.toolCall.arguments)}
- Tool Execution Success: ${step.toolResult?.success ?? false}
- Tool Result Data: ${json.encode(step.toolResult?.data ?? {})}
  Error: ${step.toolResult?.error ?? 'None'}
- Observation: ${step.observation ?? 'None'}
''';
}).join('\n')}

Instructions:
1. Re-evaluate goals. Check if the latest step's tool result or retrieved knowledge resolved any pending goals. If yes, move them to completedGoals with an explanation.
2. If this is the first iteration, initialize the goals list in "remainingGoals" based on what the user wants. E.g. search hostels, check refund, check-in instructions.
3. If parameters like budget, city, or university are required to search or book but not provided in the request or memory, set "needUserClarification" to true and write a polite "clarificationQuestion".
4. If you need to search external domain rules, guides, or policies (e.g. refund rules, cancellation guides, check-in guides) before taking action, populate a "nextKnowledgeGoal" with category and query to trigger retrieval. Do NOT execute tool calling in this step.
5. If you have already executed a search tool and have unranked hostels in Working Memory or Tool History, and the user needs a personalized recommendation, populate "nextRecommendationGoal". Do NOT execute tool calling in this step.
6. If all goals are satisfied, set "finished" to true and "stopReason" to "GoalCompleted".
7. If more info is needed, set "finished" to false. Write a clear "plannerReasoning" explaining what action/search/lookup you require next.
8. Generate a "newObservation" from the latest tool outcome.
9. Extract key facts/values from the latest tool result data into "newWorkingMemoryFacts".
''';

      PlanningResult result;
      try {
        final response = await model.generateContent(
          [Content.text(systemInstruction)],
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: planningSchema,
          ),
        );

        final text = response.text?.trim() ?? '';
        var cleanText = text;
        if (cleanText.startsWith('```')) {
          cleanText = cleanText.replaceAll('```json', '').replaceAll('```', '').trim();
        }
        final parsed = json.decode(cleanText) as Map<String, dynamic>;
        result = PlanningResult.fromMap(parsed);
      } catch (e) {
        state.stopReason = 'ToolFailure';
        break;
      }

      // Merge planner changes into ExecutionState
      state.goals.clear();
      state.goals.addAll(result.remainingGoals);
      state.goals.addAll(result.completedGoals);

      if (result.newObservation != null && result.newObservation!.isNotEmpty) {
        state.observations.add(PlannerObservation(
          toolName: state.steps.isEmpty ? 'initial' : state.steps.last.toolCall.toolName,
          observation: result.newObservation!,
          timestamp: DateTime.now(),
        ));
      }

      if (result.newWorkingMemoryFacts != null) {
        final mutable = Map<String, dynamic>.from(state.workingMemory.facts);
        mutable.addAll(result.newWorkingMemoryFacts!);
        state.workingMemory.facts = mutable;
      }

      // Check termination flags
      if (result.needUserClarification) {
        state.stopReason = 'NeedUserClarification';
        state.steps.add(PlanningStep(
          toolCall: ToolCall(
            toolName: 'general_inquiry',
            arguments: {},
            confidence: 1.0,
            reasoning: result.plannerReasoning,
          ),
          plannerReasoning: result.plannerReasoning,
          observation: result.clarificationQuestion,
        ));
        break;
      }

      if (result.finished) {
        // Final Reflection Review before returning Response
        final reflectionResult = await _reflectionManager.reflect(
          state, 
          ReflectionMode.finalReview, 
          ReflectionConfig()
        );

        if (reflectionResult.isComplete) {
          state.stopReason = reflectionResult.stopReason.isNotEmpty 
            ? reflectionResult.stopReason 
            : (result.stopReason ?? 'GoalCompleted');
          break;
        } else if (reflectionResult.recommendedAction == ReflectionAction.askUserClarification) {
          state.stopReason = 'NeedUserClarification';
          final firstIssue = reflectionResult.issues.firstWhere(
            (i) => i.issueType == 'ClarificationRequired' || i.severity == ReflectionSeverity.critical,
            orElse: () => reflectionResult.issues.first,
          );
          state.steps.add(PlanningStep(
            toolCall: ToolCall(
              toolName: 'general_inquiry',
              arguments: {},
              confidence: 1.0,
              reasoning: firstIssue.description,
            ),
            plannerReasoning: firstIssue.suggestedFix,
            observation: firstIssue.description,
          ));
          break;
        } else if (reflectionResult.recommendedAction == ReflectionAction.terminate) {
          state.stopReason = reflectionResult.stopReason.isNotEmpty 
            ? reflectionResult.stopReason 
            : 'SafetyLimitReached';
          break;
        } else {
          // Auto-repair logic (continue planning with feedback)
          state.observations.add(PlannerObservation(
            toolName: 'reflection_agent',
            observation: 'Final Review Failed. Issues: ${reflectionResult.issues.map((i) => i.description).join('; ')}. Suggestion: ${reflectionResult.issues.firstOrNull?.suggestedFix}',
            timestamp: DateTime.now(),
          ));
          // Continue planning to attempt auto-repair
          state.currentIteration++;
          continue;
        }
      }

      // Loop safety checks
      if (result.plannerConfidence < 0.4) {
        state.stopReason = 'PlannerConfidenceTooLow';
        break;
      }

      // Agentic RAG branch: Executed before tool calling if nextKnowledgeGoal is specified
      if (result.nextKnowledgeGoal != null) {
        // Prevent duplicate knowledge goals to stop infinite RAG loops
        if (state.steps.any((s) =>
            s.toolCall.toolName == 'knowledge_retrieval' &&
            s.toolCall.arguments['query'] == result.nextKnowledgeGoal!.query)) {
          state.stopReason = 'SafetyLimitReached';
          break;
        }

        final config = KnowledgeRetrievalConfig(
          categoryFilters: [result.nextKnowledgeGoal!.category],
        );
        final ragContext = await _knowledgeManager.retrieve(
          result.nextKnowledgeGoal!.query,
          result.nextKnowledgeGoal!.reason,
          config: config,
        );

        // Merge KnowledgeContext
        final List<RetrievalResult> mergedChunks = List<RetrievalResult>.from(state.knowledgeContext.retrievedChunks);
        for (final res in ragContext.retrievedChunks) {
          if (!mergedChunks.any((c) => c.chunk.id == res.chunk.id)) {
            mergedChunks.add(res);
          }
        }
        final List<String> mergedGaps = List<String>.from(state.knowledgeContext.knowledgeGaps)
          ..addAll(ragContext.knowledgeGaps);
        final List<String> mergedCitations = List<String>.from(state.knowledgeContext.citations)
          ..addAll(ragContext.citations);

        state.knowledgeContext = KnowledgeContext(
          retrievedChunks: mergedChunks,
          retrievalConfidence: ragContext.retrievalConfidence,
          retrievalReason: ragContext.retrievalReason,
          knowledgeGaps: mergedGaps,
          citations: mergedCitations,
          sourceMetadata: {
            ...state.knowledgeContext.sourceMetadata,
            ...ragContext.sourceMetadata,
          },
        );

        // Add special RAG step to planning history
        state.steps.add(PlanningStep(
          toolCall: ToolCall(
            toolName: 'knowledge_retrieval',
            arguments: {
              'query': result.nextKnowledgeGoal!.query,
              'category': result.nextKnowledgeGoal!.category
            },
            confidence: 1.0,
            reasoning: result.nextKnowledgeGoal!.reason,
          ),
          plannerReasoning: 'Knowledge Goal Generated: ${result.nextKnowledgeGoal!.reason}',
          observation: 'Knowledge retrieved: ${ragContext.retrievalReason}',
        ));

        state.currentIteration++;
        continue; // Proceed directly to next evaluation iteration with enriched KnowledgeContext
      }

      // Agentic Recommendation branch: Execute LLM scoring & ranking
      if (result.nextRecommendationGoal != null) {
        // Prevent infinite loops if recommendation fails to progress state
        if (state.steps.any((s) => s.toolCall.toolName == 'recommendation_engine')) {
          state.stopReason = 'SafetyLimitReached';
          break;
        }

        final config = RecommendationConfig(
          scoringWeights: {
            'budget': 0.25,
            'distance': 0.2,
            'rating': 0.2,
            'preferences': 0.25,
            'policy': 0.1,
          },
        );

        final recContext = await _recommendationManager.generateRecommendations(
          state,
          result.nextRecommendationGoal!,
          config,
        );

        state.recommendationContext = recContext;

        // Add special Recommendation step to planning history
        state.steps.add(PlanningStep(
          toolCall: ToolCall(
            toolName: 'recommendation_engine',
            arguments: {
              'objective': result.nextRecommendationGoal!.objective,
            },
            confidence: 1.0,
            reasoning: 'Generated intelligent recommendations.',
          ),
          plannerReasoning: 'Recommendation Goal Generated: ${result.nextRecommendationGoal!.objective}',
          observation: 'Recommendations generated with confidence ${recContext.recommendationConfidence.toStringAsFixed(2)}. Tradeoffs: ${recContext.recommendationTradeoffs.join(', ')}',
        ));

        state.currentIteration++;
        continue; // Proceed directly to next evaluation iteration with enriched RecommendationContext
      }

      // Delegate tool selection to ToolCallingAgent
      final toolCall = await _callingAgent.selectTool(
        message,
        role,
        plannerReasoning: result.plannerReasoning,
        workingMemory: state.workingMemory.toMap(),
      );

      // Check for duplicate tool calls
      if (_isDuplicateCall(state.steps, toolCall)) {
        state.stopReason = 'DuplicateExecution';
        break;
      }

      // Check for duplicate reasoning (no progress)
      if (_isDuplicateReasoning(state.steps, result.plannerReasoning)) {
        state.stopReason = 'SafetyLimitReached';
        break;
      }

      // Validate the ToolCall
      final validation = ToolValidator.validate(toolCall.toolName, toolCall.arguments, role);
      final isValid = validation['isValid'] as bool? ?? false;
      final validationError = validation['error'] as String?;

      ToolResult toolResult;
      if (!isValid || validationError != null) {
        ToolLogger.logValidationError(toolCall.toolName, role, toolCall.arguments, validationError ?? 'Validation failed');
        toolResult = ToolResult(
          toolName: toolCall.toolName,
          success: false,
          data: {},
          error: validationError ?? 'Validation failed',
          executionTime: Duration.zero,
          confidence: toolCall.confidence,
          metadata: {'reasoning': toolCall.reasoning},
        );
      } else {
        // Execute tool
        toolResult = await _executor.execute(
          toolCall.toolName,
          toolCall.arguments,
          userId,
          role,
        );
        ToolLogger.log(toolCall.toolName, role, toolCall.arguments, toolResult);
      }

      // Record step
      state.steps.add(PlanningStep(
        toolCall: toolCall,
        toolResult: toolResult,
        plannerReasoning: result.plannerReasoning,
        observation: result.newObservation,
      ));
      state.toolExecutionHistory.add(toolResult);

      // Iterative Reflection Review
      final iterativeResult = await _reflectionManager.reflect(
        state, 
        ReflectionMode.iterative, 
        ReflectionConfig()
      );

      if (!iterativeResult.isComplete && iterativeResult.issues.isNotEmpty) {
        state.observations.add(PlannerObservation(
          toolName: 'reflection_agent',
          observation: 'Iterative reflection flagged: ${iterativeResult.issues.first.description}. Fix: ${iterativeResult.issues.first.suggestedFix}',
          timestamp: DateTime.now(),
        ));
      }

      // Handle Critical Action routing immediately
      if (iterativeResult.recommendedAction == ReflectionAction.askUserClarification) {
        state.stopReason = 'NeedUserClarification';
        final firstIssue = iterativeResult.issues.firstWhere(
          (i) => i.issueType == 'ClarificationRequired' || i.severity == ReflectionSeverity.critical,
          orElse: () => iterativeResult.issues.first,
        );
        state.steps.add(PlanningStep(
          toolCall: ToolCall(
            toolName: 'general_inquiry',
            arguments: {},
            confidence: 1.0,
            reasoning: firstIssue.description,
          ),
          plannerReasoning: firstIssue.suggestedFix,
          observation: firstIssue.description,
        ));
        break;
      }

      if (iterativeResult.recommendedAction == ReflectionAction.terminate) {
        state.stopReason = iterativeResult.stopReason.isNotEmpty 
            ? iterativeResult.stopReason 
            : 'SafetyLimitReached';
        break;
      }

      state.currentIteration++;
    }

    if (state.currentIteration >= 5 && state.stopReason == null) {
      state.stopReason = 'SafetyLimitReached';
    }

    return state;
  }

  bool _isDuplicateCall(List<PlanningStep> steps, ToolCall nextTool) {
    if (steps.isEmpty) return false;
    for (final step in steps) {
      if (step.toolCall.toolName == nextTool.toolName &&
          _mapsAreEqual(step.toolCall.arguments, nextTool.arguments)) {
        return true;
      }
    }
    return false;
  }

  bool _isDuplicateReasoning(List<PlanningStep> steps, String reasoning) {
    if (steps.isEmpty) return false;
    for (final step in steps) {
      if (step.plannerReasoning.trim().toLowerCase() == reasoning.trim().toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  bool _mapsAreEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (!map2.containsKey(key)) return false;
      if (map1[key].toString() != map2[key].toString()) return false;
    }
    return true;
  }
}

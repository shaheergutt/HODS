import 'dart:convert';
import 'dart:developer' as developer;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../models/user_model.dart';
import '../ai_types.dart';
import '../agent_executor.dart';
import '../collaboration_logger.dart';
import '../../progress/progress_models.dart';
import '../../progress/progress_event.dart';
import '../../progress/progress_manager.dart';

class SupervisorAgent {
  final GenerativeModel _model;
  final AgentExecutor _executor;
  final CollaborationLogger _logger;
  final ProgressManager? _progressManager;

  SupervisorAgent(this._model, {AgentExecutor? executor, CollaborationLogger? logger, ProgressManager? progressManager})
      : _executor = executor ?? AgentExecutor(),
        _logger = logger ?? CollaborationLogger(),
        _progressManager = progressManager;

  /// Coordinates dynamic multi-agent collaboration for a user message request.
  Future<ExecutionState> collaborate(
    String message,
    String userId,
    UserRole role, {
    WorkingMemory? initialWorkingMemory,
  }) async {
    try {
      final startTime = DateTime.now();
    _logger.logCollaborationStart(message);

    _progressManager?.emit(ProgressEvent(
      taskId: 'supervisor_plan',
      stage: ProgressStage.understandingRequest,
      status: ProgressStatus.started,
      title: 'Supervisor Agent',
      message: 'Decomposing request objectives...',
      agentName: 'SupervisorAgent',
      timestamp: DateTime.now(),
    ));

    // Initialize ExecutionState
    final state = ExecutionState(
      originalRequest: message,
      role: role,
      conversationSummary: '',
      goals: [],
      workingMemory: initialWorkingMemory ?? WorkingMemory(),
      observations: [],
      steps: [],
      toolExecutionHistory: [],
      knowledgeContext: KnowledgeContext(),
      recommendationContext: RecommendationContext(),
    );
    state.progressManager = _progressManager;

    // 1. Generate CollaborationPlan using Gemini Structured Outputs
    final planSchema = Schema.object(
      properties: {
        'executionStrategy': Schema.string(description: 'Description of the scheduling plan'),
        'estimatedComplexity': Schema.string(description: 'Estimated complexity (low, medium, high)'),
        'dependencies': Schema.array(description: 'Dependencies list between tasks', items: Schema.string()),
        'tasks': Schema.array(
          description: 'List of agent subtasks to schedule',
          items: Schema.object(
            properties: {
              'taskId': Schema.string(description: 'Unique task identifier, e.g. task_0, task_1'),
              'targetAgent': Schema.string(description: 'planning, memory, booking, knowledge, recommendation, complaint, analytics, reflection'),
              'objective': Schema.string(description: 'Clear details of what the agent should accomplish'),
              'priority': Schema.string(description: 'high, medium, low'),
            },
            requiredProperties: ['taskId', 'targetAgent', 'objective'],
          ),
        ),
      },
      requiredProperties: ['executionStrategy', 'estimatedComplexity', 'tasks'],
    );

    final planPrompt = '''
You are the HODS AI Enterprise Supervisor Agent.
Your job is to analyze the user request, break it down into specialized agent tasks, schedule them, and compile a CollaborationPlan.

User Request: "$message"
User Role: ${role.name.toUpperCase()}

Specialist Capabilities Available:
- memory: Retrieve long-term preferences, user facts, and summaries.
- planning: Coordinate goal state management, constraints tracking, and steps sequencing.
- booking: Search hostels, get details, compare, or modify bookings.
- knowledge: Retrieve domain policies, guides, or rules (RAG).
- recommendation: Score and rank hostels.
- complaint: File, lookup, or resolve complaints.
- analytics: Occupancies, platform analytics, business reviews.
- reflection: Final self-verification of the correctness of the final results.

Decomposition Rules:
1. Always schedule 'memory' first if user profile or context details are needed.
2. Schedule 'planning' to structure pending/completed goals.
3. Schedule 'booking' or 'knowledge' or 'complaint' or 'analytics' to gather facts. Booking and knowledge can run in parallel.
4. Schedule 'recommendation' if ranked lists or comparisons are requested.
5. Always schedule 'reflection' at the end to verify details.

Output a structured JSON conforming to the CollaborationPlan schema.
''';

    CollaborationPlan plan;
    try {
      final response = await _model.generateContent(
        [Content.text(planPrompt)],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: planSchema,
        ),
      );

      final text = response.text?.trim() ?? '{}';
      var cleanText = text;
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll('```json', '').replaceAll('```', '').trim();
      }

      final parsed = json.decode(cleanText) as Map<String, dynamic>;
      plan = CollaborationPlan.fromMap(parsed);

      _progressManager?.emit(ProgressEvent(
        taskId: 'supervisor_plan',
        stage: ProgressStage.understandingRequest,
        status: ProgressStatus.completed,
        title: 'Supervisor Agent',
        message: 'Formulated collaboration strategy.',
        agentName: 'SupervisorAgent',
        timestamp: DateTime.now(),
      ));
    } catch (e, stackTrace) {
      developer.log(
        '[SupervisorAgent] Error formulating CollaborationPlan: $e',
        name: 'SupervisorAgent',
        error: e,
        stackTrace: stackTrace,
      );
      // Fallback plan if structured output fails
      plan = CollaborationPlan(
        originalRequest: message,
        tasks: [
          AgentTask(taskId: 't0', targetAgent: AgentCapability.memory, objective: 'Retrieve memory preferences'),
          AgentTask(taskId: 't1', targetAgent: AgentCapability.planning, objective: 'Structure general goals'),
          AgentTask(taskId: 't2', targetAgent: AgentCapability.booking, objective: 'Retrieve hostels/bookings'),
          AgentTask(taskId: 't3', targetAgent: AgentCapability.reflection, objective: 'Self-verify results'),
        ],
        executionStrategy: 'Sequential fallback execution strategy.',
        dependencies: [],
        estimatedComplexity: 'medium',
      );
    }

    final activeTasks = List<AgentTask>.from(plan.tasks);
    final completedTasks = <AgentTask>[];
    final failedTasks = <AgentTask>[];
    final agentResults = <String, AgentResult>{};
    final collaborationHistory = <AgentMessage>[];

    final colState = CollaborationState(
      activeTasks: activeTasks,
      completedTasks: completedTasks,
      failedTasks: failedTasks,
      agentResults: agentResults,
      mergedWorkingMemory: state.workingMemory,
      collaborationHistory: collaborationHistory,
    );

    // 2. Stage-based Execution Loop
    // Stage 1: Memory
    final memoryTasks = plan.tasks.where((t) => t.targetAgent == AgentCapability.memory).toList();
    for (final task in memoryTasks) {
      final mutableRequired = Map<String, dynamic>.from(task.requiredInputs);
      mutableRequired['userId'] = userId;
      task.requiredInputs = mutableRequired;
      final res = await _executor.executeTask(task, state);
      agentResults[task.taskId] = res;
      if (res.success) {
        task.status = 'completed';
        completedTasks.add(task);
      } else {
        task.status = 'failed';
        failedTasks.add(task);
      }
    }

    // Stage 2: Parallel Specialists (Planning, Booking, Knowledge, Complaint, Analytics)
    final parallelTasks = plan.tasks.where((t) =>
        t.targetAgent == AgentCapability.planning ||
        t.targetAgent == AgentCapability.booking ||
        t.targetAgent == AgentCapability.knowledge ||
        t.targetAgent == AgentCapability.complaint ||
        t.targetAgent == AgentCapability.analytics).toList();

    if (parallelTasks.isNotEmpty) {
      final futures = parallelTasks.map((task) async {
        final mutableRequired = Map<String, dynamic>.from(task.requiredInputs);
        mutableRequired['userId'] = userId;
        task.requiredInputs = mutableRequired;
        task.status = 'running';
        final res = await _executor.executeTask(task, state);
        agentResults[task.taskId] = res;
        if (res.success) {
          task.status = 'completed';
          completedTasks.add(task);
        } else {
          task.status = 'failed';
          failedTasks.add(task);
        }
      }).toList();

      await Future.wait(futures);
    }

    // Stage 3: Recommendation
    final recTasks = plan.tasks.where((t) => t.targetAgent == AgentCapability.recommendation).toList();
    for (final task in recTasks) {
      final mutableRequired = Map<String, dynamic>.from(task.requiredInputs);
      mutableRequired['userId'] = userId;
      task.requiredInputs = mutableRequired;
      final res = await _executor.executeTask(task, state);
      agentResults[task.taskId] = res;
      if (res.success) {
        task.status = 'completed';
        completedTasks.add(task);
      } else {
        task.status = 'failed';
        failedTasks.add(task);
      }
    }

    // Stage 4: Reflection (Verification & Repair Loop)
    final reflectionTasks = plan.tasks.where((t) => t.targetAgent == AgentCapability.reflection).toList();
    if (reflectionTasks.isEmpty) {
      reflectionTasks.add(AgentTask(
        taskId: 'reflection_task',
        targetAgent: AgentCapability.reflection,
        objective: 'Verify complete multi-agent collaboration outcome constraints.',
      ));
    }

    int reflectionCycle = 0;
    while (reflectionCycle < 2) {
      reflectionCycle++;
      final refTask = reflectionTasks.first;
      final mutableRequired = Map<String, dynamic>.from(refTask.requiredInputs);
      mutableRequired['userId'] = userId;
      refTask.requiredInputs = mutableRequired;
      
      final res = await _executor.executeTask(refTask, state);
      agentResults[refTask.taskId] = res;

      if (res.success) {
        refTask.status = 'completed';
        if (!completedTasks.contains(refTask)) completedTasks.add(refTask);
        state.stopReason = 'GoalCompleted';
        break;
      } else {
        refTask.status = 'failed';
        if (!failedTasks.contains(refTask)) failedTasks.add(refTask);

        // Resolve Conflicts if contradictions found
        if (state.reflectionResult != null && state.reflectionResult!.contradictions.isNotEmpty) {
          await _resolveConflicts(state);
        }

        // Auto-Repair routing logic
        if (state.reflectionResult != null && !state.reflectionResult!.isComplete) {
          final r = state.reflectionResult!;
          
          if (r.recommendedAction == ReflectionAction.askUserClarification) {
            state.stopReason = 'NeedUserClarification';
            break;
          } else if (r.recommendedAction == ReflectionAction.terminate) {
            state.stopReason = r.stopReason.isNotEmpty ? r.stopReason : 'SafetyLimitReached';
            break;
          } else {
            // Re-route repair to correct specialist capability
            final repairAgent = r.recommendedAction == ReflectionAction.executeTool
                ? AgentCapability.booking
                : AgentCapability.knowledge;
            
            final repairTask = AgentTask(
              taskId: 'repair_task_$reflectionCycle',
              targetAgent: repairAgent,
              objective: r.issues.firstOrNull?.suggestedFix ?? 'Resolve constraint conflict',
            );
            final mutableRequired = Map<String, dynamic>.from(repairTask.requiredInputs);
            mutableRequired['userId'] = userId;
            repairTask.requiredInputs = mutableRequired;
            
            final repairRes = await _executor.executeTask(repairTask, state);
            agentResults[repairTask.taskId] = repairRes;
          }
        } else {
          break;
        }
      }
    }

    _logger.logCollaborationEnd(colState, DateTime.now().difference(startTime).inMilliseconds);
    return state;
    } catch (e, stackTrace) {
      developer.log(
        '[SupervisorAgent] Fatal error during collaboration: $e',
        name: 'SupervisorAgent',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Resolves disagreements/contradictions using dynamic LLM feedback.
  Future<void> _resolveConflicts(ExecutionState state) async {
    final contradictions = state.reflectionResult?.contradictions ?? [];
    if (contradictions.isEmpty) return;

    final prompt = '''
You are the HODS AI Supervisor Conflict Resolver.
The Reflection Agent identified the following contradictions/conflicts in the multi-agent collaboration state:
${contradictions.map((c) => '- $c').join('\n')}

Working Memory Facts: ${json.encode(state.workingMemory.toMap())}
Retrieved Knowledge: ${json.encode(state.knowledgeContext.toMap())}

Please resolve this conflict. Choose the correct verified outcome and output the resolved fact values to update the Working Memory.
For example, if knowledge says "refund is allowed over 48h" and booking status says "cancellation was less than 24h", the cancellation is non-refundable.

Format your output strictly as a JSON object:
{
  "conflictExplanation": "string",
  "resolvedFacts": {
    "refundPolicy": "string",
    "selectedBooking": "string"
  }
}
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '{}';
      var cleanText = text;
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll('```json', '').replaceAll('```', '').trim();
      }
      final parsed = json.decode(cleanText) as Map<String, dynamic>;
      
      _logger.logConflict(
        contradictions.join('; '),
        parsed['conflictExplanation'] ?? 'Conflict resolved by Supervisor.'
      );

      final Map<String, dynamic> resolvedFacts = Map<String, dynamic>.from(parsed['resolvedFacts'] ?? {});
      final mutable = Map<String, dynamic>.from(state.workingMemory.facts);
      mutable.addAll(resolvedFacts);
      state.workingMemory.facts = mutable;

    } catch (e, stackTrace) {
      developer.log(
        '[SupervisorAgent] Error resolving conflicts: $e',
        name: 'SupervisorAgent',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

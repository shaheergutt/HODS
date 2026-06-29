import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../ai_types.dart';
import '../specialist_agent.dart';
import '../knowledge_manager.dart';
import '../../progress/progress_models.dart';
import '../../progress/progress_event.dart';
import '../../progress/progress_manager.dart';

class KnowledgeAgent implements SpecialistAgent {
  final GenerativeModel _model;
  final KnowledgeManager _knowledgeManager;
  final ProgressManager? _progressManager;

  KnowledgeAgent(this._model, {KnowledgeManager? knowledgeManager, ProgressManager? progressManager}) 
      : _knowledgeManager = knowledgeManager ?? KnowledgeManager(_model),
        _progressManager = progressManager;

  @override
  AgentCapability get capability => AgentCapability.knowledge;

  @override
  Future<AgentResult> execute(AgentTask task, ExecutionState state) async {
    final startTime = DateTime.now();

    _progressManager?.emit(ProgressEvent(
      taskId: task.taskId,
      stage: ProgressStage.checkingPolicies,
      status: ProgressStatus.started,
      title: 'Knowledge RAG',
      message: 'Searching hostel policies...',
      agentName: 'KnowledgeAgent',
      timestamp: DateTime.now(),
    ));

    final prompt = '''
You are the HODS Knowledge Specialist Agent.
Your job is to formulate a RAG query to retrieve policy files, rules, or FAQs from the HODS knowledge base.

Task Objective: "${task.objective}"
User Request: "${state.originalRequest}"
Working Memory Facts: ${json.encode(state.workingMemory.toMap())}

Please output a structured search query. If no knowledge base query is required, set "requireSearch" to false.

Format your output strictly as a JSON object:
{
  "requireSearch": bool,
  "query": "string",
  "reason": "string",
  "category": "policies" | "hostel_rules" | "owner_guides" | "admin_guides" | "faqs"
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

      if (parsed['requireSearch'] == true) {
        final String query = parsed['query'] ?? '';
        final String reason = parsed['reason'] ?? '';
        final String category = parsed['category'] ?? 'policies';

        final config = KnowledgeRetrievalConfig(
          categoryFilters: [category],
        );

        // Customize dynamic status message based on search intent
        String runMessage = 'Looking up hostel policies...';
        if (query.toLowerCase().contains('refund')) {
          runMessage = 'Checking refund rules...';
        } else if (query.toLowerCase().contains('cancel')) {
          runMessage = 'Reading cancellation guidelines...';
        }
        
        _progressManager?.emit(ProgressEvent(
          taskId: task.taskId,
          stage: ProgressStage.checkingPolicies,
          status: ProgressStatus.running,
          title: 'Knowledge RAG',
          message: runMessage,
          agentName: 'KnowledgeAgent',
          timestamp: DateTime.now(),
        ));

        final ragContext = await _knowledgeManager.retrieve(
          query,
          reason,
          config: config,
        );

        // Merge knowledge chunks into execution state
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

        // Record a step in ExecutionState
        state.steps.add(PlanningStep(
          toolCall: ToolCall(
            toolName: 'knowledge_retrieval',
            arguments: {'query': query, 'category': category},
            confidence: 1.0,
            reasoning: reason,
          ),
          plannerReasoning: 'Knowledge Goal Generated: $reason',
          observation: 'Knowledge retrieved: ${ragContext.retrievalReason}',
        ));

        _progressManager?.emit(ProgressEvent(
          taskId: task.taskId,
          stage: ProgressStage.checkingPolicies,
          status: ProgressStatus.completed,
          title: 'Knowledge RAG',
          message: 'Retrieved matching policy and rule documents.',
          agentName: 'KnowledgeAgent',
          timestamp: DateTime.now(),
        ));

        return AgentResult(
          taskId: task.taskId,
          agentName: 'KnowledgeAgent',
          success: true,
          confidence: ragContext.retrievalConfidence,
          outputs: ragContext.toMap(),
          observations: [reason, 'Retrieved ${ragContext.retrievedChunks.length} chunks. Query: $query'],
          executionTime: DateTime.now().difference(startTime),
        );
      } else {
        _progressManager?.emit(ProgressEvent(
          taskId: task.taskId,
          stage: ProgressStage.checkingPolicies,
          status: ProgressStatus.completed,
          title: 'Knowledge RAG',
          message: 'No policy queries required.',
          agentName: 'KnowledgeAgent',
          timestamp: DateTime.now(),
        ));

        return AgentResult(
          taskId: task.taskId,
          agentName: 'KnowledgeAgent',
          success: true,
          confidence: 1.0,
          outputs: {},
          observations: [parsed['reason'] ?? 'No knowledge query needed.'],
          executionTime: DateTime.now().difference(startTime),
        );
      }
    } catch (e) {
      _progressManager?.emit(ProgressEvent(
        taskId: task.taskId,
        stage: ProgressStage.checkingPolicies,
        status: ProgressStatus.failed,
        severity: ProgressSeverity.error,
        title: 'Knowledge RAG Failed',
        message: e.toString(),
        agentName: 'KnowledgeAgent',
        timestamp: DateTime.now(),
      ));

      return AgentResult(
        taskId: task.taskId,
        agentName: 'KnowledgeAgent',
        success: false,
        confidence: 0.0,
        outputs: {},
        observations: ['Knowledge retrieval failed: ${e.toString()}'],
        executionTime: DateTime.now().difference(startTime),
      );
    }
  }
}

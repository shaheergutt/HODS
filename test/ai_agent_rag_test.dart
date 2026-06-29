import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hods/models/user_model.dart';
import 'package:hods/services/ai/ai_types.dart';
import 'package:hods/services/ai/tool_calling_agent.dart';
import 'package:hods/services/ai/tool_executor.dart';
import 'package:hods/services/ai/agents/planner_agent.dart';
import 'package:hods/services/ai/agents/response_generator.dart';
import 'package:hods/services/ai/knowledge_retriever.dart';
import 'package:hods/services/ai/knowledge_manager.dart';
import 'package:hods/services/ai/agent_registry.dart';
import 'package:hods/services/ai/agents/supervisor_agent.dart';
import 'package:hods/services/ai/agents/planning_agent.dart';
import 'package:hods/services/ai/agents/memory_agent.dart';
import 'package:hods/services/ai/agents/reflection_agent_specialist.dart';
import 'package:hods/services/ai/reflection_manager.dart';
import 'package:hods/services/ai/memory_manager.dart';
import 'package:http/http.dart' as http;

// A custom HTTP client to mock API calls from the google_generative_ai package
class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) sendCallback;

  MockHttpClient(this.sendCallback);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await sendCallback(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

// A mock retriever that returns pre-configured chunks for testing.
class MockKnowledgeRetriever implements KnowledgeRetriever {
  final List<KnowledgeChunk> mockChunks;

  MockKnowledgeRetriever(this.mockChunks);

  @override
  Future<List<KnowledgeChunk>> retrieve(
    String queryText,
    KnowledgeRetrievalConfig config,
  ) async {
    if (config.categoryFilters.isNotEmpty) {
      return mockChunks.where((c) => config.categoryFilters.contains(c.category)).toList();
    }
    return mockChunks;
  }
}

// A mock tool executor to avoid instantiating tools that access Firebase
class MockToolExecutor implements ToolExecutor {
  @override
  Future<ToolResult> execute(
    String toolName,
    Map<String, dynamic> arguments,
    String userId,
    UserRole role,
  ) async {
    return ToolResult(
      toolName: toolName,
      success: true,
      data: {},
      executionTime: Duration.zero,
      metadata: {},
    );
  }
}

// A mock memory manager to avoid instantiating Firestore
class MockMemoryManager implements MemoryManager {
  @override
  Future<MemoryContext> retrieveMemoryContext(String userId, MemoryRetrievalConfig config) async {
    return MemoryContext(
      conversationSummaries: const [],
      preferences: const [],
      userFacts: const [],
    );
  }

  @override
  Future<void> saveMemoryUpdate(String userId, MemoryUpdate update, String source) async {
    // no-op
  }

  @override
  WorkingMemory mergeToWorkingMemory(MemoryContext memContext, WorkingMemory currentWorkingMemory) {
    return currentWorkingMemory;
  }
}

void main() {
  group('HODS AI Agentic RAG and Clarification Tests', () {
    test('Verify RAG loop for policy query "Can I cancel my monthly booking and get a refund?"', () async {
      int plannerCallCount = 0;

      final mockClient = MockHttpClient((request) async {
        String bodyString = '';
        if (request is http.Request) {
          bodyString = request.body;
        }

        String mockTextResponse = '';

        if (bodyString.contains('HODS AI Goal-Oriented Planner')) {
          if (plannerCallCount == 0) {
            mockTextResponse = json.encode({
              'finished': false,
              'plannerReasoning': 'Need to check HODS knowledge base for policies regarding monthly booking cancellations and refunds.',
              'plannerConfidence': 0.95,
              'goalCompleted': false,
              'needUserClarification': false,
              'remainingGoals': [
                {
                  'description': 'Check monthly stay cancellation and refund policy',
                  'status': 'pending',
                  'priority': 'high'
                }
              ],
              'completedGoals': [],
              'nextKnowledgeGoal': {
                'reason': 'Verify refund eligibility rules and check-in timeline constraints',
                'query': 'monthly booking cancellation refund policy',
                'category': 'policies',
                'priority': 'high'
              }
            });
          } else {
            mockTextResponse = json.encode({
              'finished': true,
              'plannerReasoning': 'Retrieved monthly cancellation guidelines. They state that monthly stays require 30 days notice to be eligible for any refund.',
              'plannerConfidence': 0.98,
              'goalCompleted': true,
              'needUserClarification': false,
              'remainingGoals': [],
              'completedGoals': [
                {
                  'description': 'Check monthly stay cancellation and refund policy',
                  'status': 'completed',
                  'priority': 'high',
                  'completionReason': 'Retrieved policy and confirmed 30-day notice is required.'
                }
              ],
              'newObservation': 'Confirmed cancellation policy: 30 days notice is required for monthly stays.',
              'newWorkingMemoryFacts': {
                'refundPolicy': 'Monthly stays require 30 days notice for refund eligibility.'
              }
            });
          }
          plannerCallCount++;
        } else if (bodyString.contains('HODS AI Semantic Ranking Engine')) {
          mockTextResponse = json.encode({
            'evaluations': [
              {
                'chunkId': 'monthly_stay_cancellation',
                'relevanceScore': 0.95,
                'confidence': 0.9,
                'reasoning': 'Directly explains monthly stay cancellation notice and refund rules.'
              },
              {
                'chunkId': 'daily_stay_refund_policy',
                'relevanceScore': 0.3,
                'confidence': 0.8,
                'reasoning': 'Only describes daily tourist stays, not monthly.'
              }
            ]
          });
        } else if (bodyString.contains('HODS AI Response Generator')) {
          mockTextResponse = 
              'According to HODS policy (HODS Monthly Stay Cancellation Policy), monthly student stays require a 30-day notice prior to check-in to be eligible for a refund.';
        } else if (bodyString.contains('HODS AI Enterprise Reflection Agent')) {
          mockTextResponse = json.encode({
            'isComplete': true,
            'plannerConfidence': 0.98,
            'reflectionConfidence': 0.98,
            'stopReason': 'GoalCompleted',
            'satisfiedGoals': ['Check monthly stay cancellation and refund policy'],
            'missingGoals': [],
            'violatedConstraints': [],
            'contradictions': [],
            'issues': []
          });
        } else {
          mockTextResponse = '{}';
        }

        final responseJson = json.encode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': mockTextResponse
                  }
                ]
              }
            }
          ]
        });

        return http.Response(responseJson, 200, headers: {'content-type': 'application/json'});
      });

      final mockModel = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: 'mock_api_key',
        httpClient: mockClient,
      );

      // Seed mock knowledge document retriever
      final mockChunks = [
        KnowledgeChunk(
          id: 'monthly_stay_cancellation',
          documentId: 'cancellation_guidelines',
          documentTitle: 'HODS Monthly Stay Cancellation Policy',
          sectionTitle: 'Notice Period & Fees',
          category: 'policies',
          content: 'Monthly student stays require 30 days notice for cancellation to receive any refund. Daily bookings cancelled over 48 hours get 100% refund.',
          tags: ['refund', 'monthly stay'],
          keywords: ['refund', 'cancel'],
          importanceScore: 0.9,
          metadata: {},
          lastUpdated: DateTime.now(),
        ),
        KnowledgeChunk(
          id: 'daily_stay_refund_policy',
          documentId: 'daily_stay_refund_policy',
          documentTitle: 'HODS Daily Booking Cancellation & Refund Policy',
          sectionTitle: 'Daily Refund Eligibility',
          category: 'policies',
          content: 'Daily bookings (Tourist stays) cancelled more than 48 hours before check-in receive 100% refund.',
          tags: ['refund', 'daily stay'],
          keywords: ['refund', 'cancel'],
          importanceScore: 0.8,
          metadata: {},
          lastUpdated: DateTime.now(),
        ),
      ];

      final mockRetriever = MockKnowledgeRetriever(mockChunks);
      final knowledgeManager = KnowledgeManager(mockModel, retriever: mockRetriever);

      final callingAgent = ToolCallingAgent(mockModel);
      final mockExecutor = MockToolExecutor();
      final plannerAgent = PlannerAgent(
        callingAgent,
        knowledgeManager: knowledgeManager,
        executor: mockExecutor,
      );

      // Execute reasoning loop
      final state = await plannerAgent.executePlan(
        'Can I cancel my monthly booking and get a refund?',
        'test-user-id',
        UserRole.student,
      );

      // Assertions
      expect(state.currentIteration, equals(1)); // Iteration 0 (RAG goal) + Iteration 1 (Finish)
      expect(state.stopReason, equals('GoalCompleted'));
      expect(state.goals.length, equals(1));
      expect(state.goals.first.status, equals('completed'));
      expect(state.workingMemory.facts['refundPolicy'], contains('30 days notice'));
      
      // Verify knowledge context was updated and citations exist
      expect(state.knowledgeContext.retrievedChunks.length, equals(2));
      expect(state.knowledgeContext.retrievedChunks.first.chunk.id, equals('monthly_stay_cancellation'));
      expect(state.knowledgeContext.citations, contains(contains('HODS Monthly Stay Cancellation Policy')));

      // Test response generation with this state
      final responseGen = ResponseGenerator(mockModel);
      final responseText = await responseGen.generate(
        'Can I cancel my monthly booking and get a refund?',
        UserRole.student,
        '',
        state,
        MemoryContext(),
        state.knowledgeContext,
        state.recommendationContext,
      );

      expect(responseText, contains('monthly student stays require a 30-day notice'));
    });

    test('Verify conflict clarification when city/budget info is missing', () async {
      final mockClient = MockHttpClient((request) async {
        String bodyString = '';
        if (request is http.Request) {
          bodyString = request.body;
        }

        String mockTextResponse = '';

        if (bodyString.contains('HODS AI Goal-Oriented Planner')) {
          mockTextResponse = json.encode({
            'finished': false,
            'plannerReasoning': 'Cannot search for hostels without knowing the target city or budget limit.',
            'plannerConfidence': 0.9,
            'goalCompleted': false,
            'needUserClarification': true,
            'clarificationQuestion': 'I can help you search for a hostel. Could you please specify which city you are looking in, and what your approximate budget is?',
            'remainingGoals': [
              {
                'description': 'Search hostels with user constraints',
                'status': 'pending',
                'priority': 'medium'
              }
            ],
            'completedGoals': []
          });
        } else if (bodyString.contains('HODS AI Response Generator')) {
          mockTextResponse = 'Could you please specify which city you are looking in, and what your approximate budget is?';
        } else {
          mockTextResponse = '{}';
        }

        final responseJson = json.encode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': mockTextResponse
                  }
                ]
              }
            }
          ]
        });

        return http.Response(responseJson, 200, headers: {'content-type': 'application/json'});
      });

      final mockModel = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: 'mock_api_key',
        httpClient: mockClient,
      );

      final mockRetriever = MockKnowledgeRetriever([]);
      final knowledgeManager = KnowledgeManager(mockModel, retriever: mockRetriever);

      final callingAgent = ToolCallingAgent(mockModel);
      final mockExecutor = MockToolExecutor();
      final plannerAgent = PlannerAgent(
        callingAgent,
        knowledgeManager: knowledgeManager,
        executor: mockExecutor,
      );

      // Execute reasoning loop
      final state = await plannerAgent.executePlan(
        'I want to search for a hostel',
        'test-user-id',
        UserRole.student,
      );

      // Assertions
      expect(state.currentIteration, equals(0)); // Loop breaks immediately without increments
      expect(state.stopReason, equals('NeedUserClarification'));
      expect(state.steps.length, equals(1));
      expect(state.steps.last.observation, contains('Could you please specify which city'));
      
      // Verify RAG step did NOT run
      expect(state.knowledgeContext.retrievedChunks, isEmpty);

      // Generate response and verify it asks the clarification question
      final responseGen = ResponseGenerator(mockModel);
      final responseText = await responseGen.generate(
        'I want to search for a hostel',
        UserRole.student,
        '',
        state,
        MemoryContext(),
        state.knowledgeContext,
        state.recommendationContext,
      );

      expect(responseText, contains('Could you please specify which city'));
    });

    test('Verify SupervisorAgent multi-agent collaboration flow', () async {
      final mockClient = MockHttpClient((request) async {
        String bodyString = '';
        if (request is http.Request) {
          bodyString = request.body;
        }

        String mockTextResponse = '';

        if (bodyString.contains('HODS AI Enterprise Supervisor Agent')) {
          mockTextResponse = json.encode({
            'executionStrategy': 'Decompose memory, planning, and reflection',
            'estimatedComplexity': 'medium',
            'dependencies': [],
            'tasks': [
              {
                'taskId': 'task_0',
                'targetAgent': 'memory',
                'objective': 'Retrieve memory'
              },
              {
                'taskId': 'task_1',
                'targetAgent': 'planning',
                'objective': 'Structure goals'
              },
              {
                'taskId': 'task_2',
                'targetAgent': 'reflection',
                'objective': 'Verify outcome'
              }
            ]
          });
        } else if (bodyString.contains('HODS Planning Specialist Agent')) {
          mockTextResponse = json.encode({
            'plannerReasoning': 'Goal structures set.',
            'goalCompleted': true,
            'newObservation': 'Planning complete.',
            'remainingGoals': [],
            'completedGoals': [
              {
                'description': 'Search hostels near FAST under 18000',
                'status': 'completed',
                'priority': 'high',
                'completionReason': 'Hostels found.'
              }
            ]
          });
        } else if (bodyString.contains('HODS AI Enterprise Reflection Agent')) {
          mockTextResponse = json.encode({
            'isComplete': true,
            'plannerConfidence': 0.98,
            'reflectionConfidence': 0.98,
            'stopReason': 'GoalCompleted',
            'satisfiedGoals': ['Search hostels near FAST under 18000'],
            'missingGoals': [],
            'violatedConstraints': [],
            'contradictions': [],
            'issues': []
          });
        } else {
          mockTextResponse = '{}';
        }

        final responseJson = json.encode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': mockTextResponse
                  }
                ]
              }
            }
          ]
        });

        return http.Response(responseJson, 200, headers: {'content-type': 'application/json'});
      });

      final mockModel = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: 'mock_api_key',
        httpClient: mockClient,
      );

      // Register agents in the registry
      final reflectionManager = ReflectionManager(mockModel);
      AgentRegistry.clear();
      AgentRegistry.register(MemoryAgent(memoryManager: MockMemoryManager()));
      AgentRegistry.register(PlanningAgent(mockModel));
      AgentRegistry.register(ReflectionAgentSpecialist(reflectionManager));

      final supervisor = SupervisorAgent(mockModel);

      // Execute collaboration
      final state = await supervisor.collaborate(
        'Find me hostels near FAST under 18000',
        'test-user-id',
        UserRole.student,
      );

      // Assertions
      expect(state.stopReason, equals('GoalCompleted'));
      expect(state.goals.length, equals(1));
      expect(state.goals.first.status, equals('completed'));
      expect(state.goals.first.description, contains('Search hostels near FAST'));
    });
  });
}

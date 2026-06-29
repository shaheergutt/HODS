import '../../models/user_model.dart';
import '../progress/progress_manager.dart';

class ToolDefinition {
  final String name;
  final String category; // Hostels, Bookings, Complaints, Roommates, Knowledge, Analytics
  final String description;
  final Map<String, dynamic> parameterSchema;
  final List<UserRole> allowedRoles; // Student, Owner, Admin

  ToolDefinition({
    required this.name,
    required this.category,
    required this.description,
    required this.parameterSchema,
    required this.allowedRoles,
  });
}

class ToolCall {
  final String toolName;
  final Map<String, dynamic> arguments;
  final double confidence;
  final String reasoning;

  ToolCall({
    required this.toolName,
    required this.arguments,
    required this.confidence,
    required this.reasoning,
  });

  factory ToolCall.fromMap(Map<String, dynamic> map) {
    return ToolCall(
      toolName: map['toolName'] ?? 'general_inquiry',
      arguments: Map<String, dynamic>.from(map['arguments'] ?? {}),
      confidence: (map['confidence'] ?? 1.0).toDouble(),
      reasoning: map['reasoning'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'toolName': toolName,
      'arguments': arguments,
      'confidence': confidence,
      'reasoning': reasoning,
    };
  }
}

class ToolResult {
  final String toolName;
  final bool success;
  final Map<String, dynamic> data;
  final String? error;
  final Duration executionTime;
  final double confidence;
  final Map<String, dynamic> metadata;

  ToolResult({
    required this.toolName,
    required this.success,
    required this.data,
    this.error,
    required this.executionTime,
    this.confidence = 1.0,
    required this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'toolName': toolName,
      'success': success,
      'data': data,
      'error': error,
      'executionTimeMs': executionTime.inMilliseconds,
      'confidence': confidence,
      'metadata': metadata,
    };
  }
}

class RecommendationWeights {
  final double price;
  final double distance;
  final double rating;
  final double amenities;

  RecommendationWeights({
    required this.price,
    required this.distance,
    required this.rating,
    required this.amenities,
  });

  factory RecommendationWeights.fromMap(Map<String, dynamic> map) {
    return RecommendationWeights(
      price: (map['price'] ?? 0.25).toDouble(),
      distance: (map['distance'] ?? 0.40).toDouble(),
      rating: (map['rating'] ?? 0.20).toDouble(),
      amenities: (map['amenities'] ?? 0.15).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'price': price,
      'distance': distance,
      'rating': rating,
      'amenities': amenities,
    };
  }
}

class Goal {
  final String description;
  final String status; // 'pending', 'completed'
  final String priority; // 'high', 'medium', 'low'
  final List<String> dependencies;
  final String? completionReason;

  Goal({
    required this.description,
    this.status = 'pending',
    this.priority = 'medium',
    this.dependencies = const [],
    this.completionReason,
  });

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      description: map['description'] ?? '',
      status: map['status'] ?? 'pending',
      priority: map['priority'] ?? 'medium',
      dependencies: List<String>.from(map['dependencies'] ?? []),
      completionReason: map['completionReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'status': status,
      'priority': priority,
      'dependencies': dependencies,
      'completionReason': completionReason,
    };
  }
}

class WorkingMemory {
  final Map<String, dynamic> facts;

  WorkingMemory([Map<String, dynamic>? facts]) : facts = facts ?? <String, dynamic>{};

  factory WorkingMemory.fromMap(Map<String, dynamic> map) {
    return WorkingMemory(Map<String, dynamic>.from(map['facts'] ?? map));
  }

  Map<String, dynamic> toMap() => facts;
}

class PlannerObservation {
  final String toolName;
  final String observation;
  final DateTime timestamp;

  PlannerObservation({
    required this.toolName,
    required this.observation,
    required this.timestamp,
  });

  factory PlannerObservation.fromMap(Map<String, dynamic> map) {
    return PlannerObservation(
      toolName: map['toolName'] ?? '',
      observation: map['observation'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'toolName': toolName,
      'observation': observation,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class PlanningStep {
  final ToolCall toolCall;
  final ToolResult? toolResult;
  final String plannerReasoning;
  final String? observation;

  PlanningStep({
    required this.toolCall,
    this.toolResult,
    required this.plannerReasoning,
    this.observation,
  });

  Map<String, dynamic> toMap() {
    return {
      'toolCall': toolCall.toMap(),
      'toolResult': toolResult?.toMap(),
      'plannerReasoning': plannerReasoning,
      'observation': observation,
    };
  }
}

class ExecutionState {
  final String originalRequest;
  final UserRole role;
  final String conversationSummary;
  int currentIteration;
  final List<PlanningStep> steps;
  final List<Goal> goals;
  final WorkingMemory workingMemory;
  final List<PlannerObservation> observations;
  final List<ToolResult> toolExecutionHistory;
  String? stopReason;
  KnowledgeContext knowledgeContext;
  RecommendationContext recommendationContext;
  ReflectionResult? reflectionResult;
  MemoryContext? memoryContext;
  final List<double> plannerConfidenceHistory;
  final List<double> reflectionConfidenceHistory;
  ProgressManager? progressManager;

  ExecutionState({
    required this.originalRequest,
    required this.role,
    this.conversationSummary = '',
    this.currentIteration = 0,
    this.steps = const [],
    this.goals = const [],
    WorkingMemory? workingMemory,
    this.observations = const [],
    this.toolExecutionHistory = const [],
    String? stopReason,
    KnowledgeContext? knowledgeContext,
    RecommendationContext? recommendationContext,
    this.reflectionResult,
    this.memoryContext,
    List<double>? plannerConfidenceHistory,
    List<double>? reflectionConfidenceHistory,
  })  : workingMemory = workingMemory ?? WorkingMemory(),
        knowledgeContext = knowledgeContext ?? KnowledgeContext(),
        recommendationContext = recommendationContext ?? RecommendationContext(),
        plannerConfidenceHistory = plannerConfidenceHistory ?? [],
        reflectionConfidenceHistory = reflectionConfidenceHistory ?? [];

  Map<String, dynamic> toMap() {
    return {
      'originalRequest': originalRequest,
      'role': role.name,
      'conversationSummary': conversationSummary,
      'currentIteration': currentIteration,
      'steps': steps.map((s) => s.toMap()).toList(),
      'goals': goals.map((g) => g.toMap()).toList(),
      'workingMemory': workingMemory.toMap(),
      'observations': observations.map((o) => o.toMap()).toList(),
      'toolExecutionHistory': toolExecutionHistory.map((h) => h.toMap()).toList(),
      'stopReason': stopReason,
      'knowledgeContext': knowledgeContext.toMap(),
      'recommendationContext': recommendationContext.toMap(),
      'reflectionResult': reflectionResult?.toMap(),
      'memoryContext': memoryContext != null ? {
        'preferences': memoryContext!.preferences.map((p) => p.toMap()).toList(),
        'userFacts': memoryContext!.userFacts.map((f) => f.toMap()).toList(),
        'conversationSummaries': memoryContext!.conversationSummaries.map((s) => s.toMap()).toList(),
      } : null,
      'plannerConfidenceHistory': plannerConfidenceHistory,
      'reflectionConfidenceHistory': reflectionConfidenceHistory,
    };
  }
}

class PlanningResult {
  final bool finished;
  final String plannerReasoning;
  final double plannerConfidence;
  final bool goalCompleted;
  final bool needUserClarification;
  final String? clarificationQuestion;
  final List<Goal> remainingGoals;
  final List<Goal> completedGoals;
  final String? stopReason;
  final String? newObservation;
  final Map<String, dynamic>? newWorkingMemoryFacts;
  final KnowledgeGoal? nextKnowledgeGoal;
  final RecommendationGoal? nextRecommendationGoal;

  PlanningResult({
    required this.finished,
    required this.plannerReasoning,
    required this.plannerConfidence,
    required this.goalCompleted,
    required this.needUserClarification,
    this.clarificationQuestion,
    required this.remainingGoals,
    required this.completedGoals,
    this.stopReason,
    this.newObservation,
    this.newWorkingMemoryFacts,
    this.nextKnowledgeGoal,
    this.nextRecommendationGoal,
  });

  factory PlanningResult.fromMap(Map<String, dynamic> map) {
    return PlanningResult(
      finished: map['finished'] as bool? ?? false,
      plannerReasoning: map['plannerReasoning'] ?? '',
      plannerConfidence: (map['plannerConfidence'] ?? 1.0).toDouble(),
      goalCompleted: map['goalCompleted'] as bool? ?? false,
      needUserClarification: map['needUserClarification'] as bool? ?? false,
      clarificationQuestion: map['clarificationQuestion'],
      remainingGoals: (map['remainingGoals'] as List?)?.map((x) => Goal.fromMap(Map<String, dynamic>.from(x))).toList() ?? [],
      completedGoals: (map['completedGoals'] as List?)?.map((x) => Goal.fromMap(Map<String, dynamic>.from(x))).toList() ?? [],
      stopReason: map['stopReason'],
      newObservation: map['newObservation'],
      newWorkingMemoryFacts: map['newWorkingMemoryFacts'] != null ? Map<String, dynamic>.from(map['newWorkingMemoryFacts']) : null,
      nextKnowledgeGoal: map['nextKnowledgeGoal'] != null ? KnowledgeGoal.fromMap(Map<String, dynamic>.from(map['nextKnowledgeGoal'])) : null,
      nextRecommendationGoal: map['nextRecommendationGoal'] != null ? RecommendationGoal.fromMap(Map<String, dynamic>.from(map['nextRecommendationGoal'])) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'finished': finished,
      'plannerReasoning': plannerReasoning,
      'plannerConfidence': plannerConfidence,
      'goalCompleted': goalCompleted,
      'needUserClarification': needUserClarification,
      'clarificationQuestion': clarificationQuestion,
      'remainingGoals': remainingGoals.map((g) => g.toMap()).toList(),
      'completedGoals': completedGoals.map((g) => g.toMap()).toList(),
      'stopReason': stopReason,
      'newObservation': newObservation,
      'newWorkingMemoryFacts': newWorkingMemoryFacts,
      'nextKnowledgeGoal': nextKnowledgeGoal?.toMap(),
      'nextRecommendationGoal': nextRecommendationGoal?.toMap(),
    };
  }
}

class ConversationMemory {
  final String id;
  final String summary;
  final String userIntent;
  final List<String> importantFacts;
  final List<String> completedGoals;
  final List<String> unresolvedGoals;
  final DateTime timestamp;
  final double importanceScore;
  final String source;
  final int schemaVersion;

  ConversationMemory({
    required this.id,
    required this.summary,
    required this.userIntent,
    required this.importantFacts,
    required this.completedGoals,
    required this.unresolvedGoals,
    required this.timestamp,
    required this.importanceScore,
    required this.source,
    required this.schemaVersion,
  });

  factory ConversationMemory.fromMap(Map<String, dynamic> map, String id) {
    return ConversationMemory(
      id: id,
      summary: map['summary'] ?? '',
      userIntent: map['userIntent'] ?? '',
      importantFacts: List<String>.from(map['importantFacts'] ?? []),
      completedGoals: List<String>.from(map['completedGoals'] ?? []),
      unresolvedGoals: List<String>.from(map['unresolvedGoals'] ?? []),
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      importanceScore: (map['importanceScore'] ?? 0.0).toDouble(),
      source: map['source'] ?? 'unknown',
      schemaVersion: (map['schemaVersion'] ?? 1) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'summary': summary,
      'userIntent': userIntent,
      'importantFacts': importantFacts,
      'completedGoals': completedGoals,
      'unresolvedGoals': unresolvedGoals,
      'timestamp': timestamp.toIso8601String(),
      'importanceScore': importanceScore,
      'source': source,
      'schemaVersion': schemaVersion,
    };
  }
}

class Preference {
  final String key;
  final dynamic value;
  final double confidence;
  final String source;
  final DateTime lastUpdated;
  final int schemaVersion;

  Preference({
    required this.key,
    required this.value,
    required this.confidence,
    required this.source,
    required this.lastUpdated,
    required this.schemaVersion,
  });

  factory Preference.fromMap(Map<String, dynamic> map, String key) {
    return Preference(
      key: key,
      value: map['value'],
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      source: map['source'] ?? 'unknown',
      lastUpdated: DateTime.parse(map['lastUpdated'] ?? DateTime.now().toIso8601String()),
      schemaVersion: (map['schemaVersion'] ?? 1) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'confidence': confidence,
      'source': source,
      'lastUpdated': lastUpdated.toIso8601String(),
      'schemaVersion': schemaVersion,
    };
  }
}

class UserFact {
  final String key;
  final String value;
  final String source;
  final DateTime timestamp;
  final double importanceScore;
  final int schemaVersion;

  UserFact({
    required this.key,
    required this.value,
    required this.source,
    required this.timestamp,
    required this.importanceScore,
    required this.schemaVersion,
  });

  factory UserFact.fromMap(Map<String, dynamic> map, String key) {
    return UserFact(
      key: key,
      value: map['value'] ?? '',
      source: map['source'] ?? 'unknown',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      importanceScore: (map['importanceScore'] ?? 0.0).toDouble(),
      schemaVersion: (map['schemaVersion'] ?? 1) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'source': source,
      'timestamp': timestamp.toIso8601String(),
      'importanceScore': importanceScore,
      'schemaVersion': schemaVersion,
    };
  }
}

class MemoryRetrievalConfig {
  final int maxConversationCount;
  final double minimumConfidence;
  final bool includePreferences;
  final bool includeFacts;
  final bool includeConversationSummaries;

  MemoryRetrievalConfig({
    this.maxConversationCount = 5,
    this.minimumConfidence = 0.3,
    this.includePreferences = true,
    this.includeFacts = true,
    this.includeConversationSummaries = true,
  });
}

class MemoryContext {
  final List<ConversationMemory> conversationSummaries;
  final List<Preference> preferences;
  final List<UserFact> userFacts;

  MemoryContext({
    this.conversationSummaries = const [],
    this.preferences = const [],
    this.userFacts = const [],
  });
}

class MemoryUpdate {
  final String conversationSummary;
  final String userIntent;
  final Map<String, String> extractedFacts;
  final Map<String, dynamic> updatedPreferences;
  final List<String> completedGoals;
  final List<String> unresolvedGoals;

  MemoryUpdate({
    required this.conversationSummary,
    required this.userIntent,
    required this.extractedFacts,
    required this.updatedPreferences,
    required this.completedGoals,
    required this.unresolvedGoals,
  });

  factory MemoryUpdate.fromMap(Map<String, dynamic> map) {
    return MemoryUpdate(
      conversationSummary: map['conversationSummary'] ?? '',
      userIntent: map['userIntent'] ?? '',
      extractedFacts: Map<String, String>.from(map['extractedFacts'] ?? {}),
      updatedPreferences: Map<String, dynamic>.from(map['updatedPreferences'] ?? {}),
      completedGoals: List<String>.from(map['completedGoals'] ?? []),
      unresolvedGoals: List<String>.from(map['unresolvedGoals'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationSummary': conversationSummary,
      'userIntent': userIntent,
      'extractedFacts': extractedFacts,
      'updatedPreferences': updatedPreferences,
      'completedGoals': completedGoals,
      'unresolvedGoals': unresolvedGoals,
    };
  }
}

class KnowledgeDocument {
  final String id;
  final String title;
  final String category;
  final Map<String, dynamic> metadata;
  final List<String> tags;
  final List<String> keywords;
  final DateTime lastUpdated;
  final String source;
  final int schemaVersion;

  KnowledgeDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.metadata,
    required this.tags,
    required this.keywords,
    required this.lastUpdated,
    required this.source,
    required this.schemaVersion,
  });

  factory KnowledgeDocument.fromMap(Map<String, dynamic> map, String id) {
    return KnowledgeDocument(
      id: id,
      title: map['title'] ?? '',
      category: map['category'] ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      tags: List<String>.from(map['tags'] ?? []),
      keywords: List<String>.from(map['keywords'] ?? []),
      lastUpdated: DateTime.parse(map['lastUpdated'] ?? DateTime.now().toIso8601String()),
      source: map['source'] ?? 'unknown',
      schemaVersion: (map['schemaVersion'] ?? 1) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'metadata': metadata,
      'tags': tags,
      'keywords': keywords,
      'lastUpdated': lastUpdated.toIso8601String(),
      'source': source,
      'schemaVersion': schemaVersion,
    };
  }
}

class KnowledgeChunk {
  final String id;
  final String documentId;
  final String documentTitle;
  final String sectionTitle;
  final String category;
  final String content;
  final List<String> tags;
  final List<String> keywords;
  final double importanceScore;
  final Map<String, dynamic> metadata;
  final DateTime lastUpdated;

  KnowledgeChunk({
    required this.id,
    required this.documentId,
    required this.documentTitle,
    required this.sectionTitle,
    required this.category,
    required this.content,
    required this.tags,
    required this.keywords,
    required this.importanceScore,
    required this.metadata,
    required this.lastUpdated,
  });

  factory KnowledgeChunk.fromMap(Map<String, dynamic> map, String id) {
    return KnowledgeChunk(
      id: id,
      documentId: map['documentId'] ?? '',
      documentTitle: map['documentTitle'] ?? '',
      sectionTitle: map['sectionTitle'] ?? '',
      category: map['category'] ?? '',
      content: map['content'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      keywords: List<String>.from(map['keywords'] ?? []),
      importanceScore: (map['importanceScore'] ?? 0.5).toDouble(),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      lastUpdated: DateTime.parse(map['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'documentTitle': documentTitle,
      'sectionTitle': sectionTitle,
      'category': category,
      'content': content,
      'tags': tags,
      'keywords': keywords,
      'importanceScore': importanceScore,
      'metadata': metadata,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

class KnowledgeGoal {
  final String reason;
  final String query;
  final String expectedAnswer;
  final String category;
  final String priority;

  KnowledgeGoal({
    required this.reason,
    required this.query,
    required this.expectedAnswer,
    required this.category,
    required this.priority,
  });

  factory KnowledgeGoal.fromMap(Map<String, dynamic> map) {
    return KnowledgeGoal(
      reason: map['reason'] ?? '',
      query: map['query'] ?? '',
      expectedAnswer: map['expectedAnswer'] ?? '',
      category: map['category'] ?? 'general',
      priority: map['priority'] ?? 'medium',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reason': reason,
      'query': query,
      'expectedAnswer': expectedAnswer,
      'category': category,
      'priority': priority,
    };
  }
}

class RetrievalResult {
  final KnowledgeChunk chunk;
  final double relevanceScore;
  final double retrievalConfidence;
  final String source;
  final String retrievalReason;

  RetrievalResult({
    required this.chunk,
    required this.relevanceScore,
    required this.retrievalConfidence,
    required this.source,
    required this.retrievalReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'chunk': chunk.toMap(),
      'relevanceScore': relevanceScore,
      'retrievalConfidence': retrievalConfidence,
      'source': source,
      'retrievalReason': retrievalReason,
    };
  }
}

class KnowledgeContext {
  final List<RetrievalResult> retrievedChunks;
  final double retrievalConfidence;
  final String retrievalReason;
  final List<String> knowledgeGaps;
  final List<String> citations;
  final Map<String, dynamic> sourceMetadata;

  KnowledgeContext({
    this.retrievedChunks = const [],
    this.retrievalConfidence = 1.0,
    this.retrievalReason = '',
    this.knowledgeGaps = const [],
    this.citations = const [],
    this.sourceMetadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'retrievedChunks': retrievedChunks.map((r) => r.toMap()).toList(),
      'retrievalConfidence': retrievalConfidence,
      'retrievalReason': retrievalReason,
      'knowledgeGaps': knowledgeGaps,
      'citations': citations,
      'sourceMetadata': sourceMetadata,
    };
  }
}

class KnowledgeRetrievalConfig {
  final int maxCandidateChunks;
  final int maxReturnedChunks;
  final double minimumConfidence;
  final List<String> categoryFilters;

  KnowledgeRetrievalConfig({
    this.maxCandidateChunks = 10,
    this.maxReturnedChunks = 3,
    this.minimumConfidence = 0.3,
    this.categoryFilters = const [],
  });
}

class RecommendationScore {
  final String criterion;
  final double weight;
  final double rawScore;
  final double weightedScore;
  final String explanation;

  RecommendationScore({
    required this.criterion,
    required this.weight,
    required this.rawScore,
    required this.weightedScore,
    required this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      'criterion': criterion,
      'weight': weight,
      'rawScore': rawScore,
      'weightedScore': weightedScore,
      'explanation': explanation,
    };
  }
}

class RecommendationCandidate {
  final String hostelId;
  final String hostelName;
  final Map<String, dynamic> hostelData;
  final List<RecommendationScore> scoreBreakdown;
  final double totalScore;
  final List<String> strengths;
  final List<String> weaknesses;

  RecommendationCandidate({
    required this.hostelId,
    required this.hostelName,
    required this.hostelData,
    required this.scoreBreakdown,
    required this.totalScore,
    this.strengths = const [],
    this.weaknesses = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'hostelId': hostelId,
      'hostelName': hostelName,
      'hostelData': hostelData,
      'scoreBreakdown': scoreBreakdown.map((s) => s.toMap()).toList(),
      'totalScore': totalScore,
      'strengths': strengths,
      'weaknesses': weaknesses,
    };
  }
}

class RecommendationContext {
  final List<RecommendationCandidate> rankedCandidates;
  final String recommendationReasoning;
  final double recommendationConfidence;
  final List<String> plannerObservations;
  final List<String> recommendationTradeoffs;

  RecommendationContext({
    this.rankedCandidates = const [],
    this.recommendationReasoning = '',
    this.recommendationConfidence = 1.0,
    this.plannerObservations = const [],
    this.recommendationTradeoffs = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'rankedCandidates': rankedCandidates.map((c) => c.toMap()).toList(),
      'recommendationReasoning': recommendationReasoning,
      'recommendationConfidence': recommendationConfidence,
      'plannerObservations': plannerObservations,
      'recommendationTradeoffs': recommendationTradeoffs,
    };
  }
}

class RecommendationGoal {
  final String objective;
  final List<String> rankingCriteria;
  final List<String> constraints;
  final String priority;
  final String expectedOutcome;

  RecommendationGoal({
    required this.objective,
    required this.rankingCriteria,
    required this.constraints,
    required this.priority,
    required this.expectedOutcome,
  });

  factory RecommendationGoal.fromMap(Map<String, dynamic> map) {
    return RecommendationGoal(
      objective: map['objective'] ?? '',
      rankingCriteria: List<String>.from(map['rankingCriteria'] ?? []),
      constraints: List<String>.from(map['constraints'] ?? []),
      priority: map['priority'] ?? 'medium',
      expectedOutcome: map['expectedOutcome'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'objective': objective,
      'rankingCriteria': rankingCriteria,
      'constraints': constraints,
      'priority': priority,
      'expectedOutcome': expectedOutcome,
    };
  }
}

class RecommendationConfig {
  final Map<String, double> scoringWeights;
  final double minimumScore;
  final int maxRecommendations;
  final String explanationDepth;
  final bool enableLLMReview;

  RecommendationConfig({
    required this.scoringWeights,
    this.minimumScore = 0.5,
    this.maxRecommendations = 3,
    this.explanationDepth = 'detailed',
    this.enableLLMReview = true,
  });
}

enum ReflectionSeverity {
  low,
  medium,
  high,
  critical
}

enum ReflectionMode {
  iterative,
  finalReview
}

enum ReflectionAction {
  continuePlanning,
  executeTool,
  retrieveKnowledge,
  reRankRecommendations,
  askUserClarification,
  generateResponse,
  terminate
}

class ReflectionIssue {
  final String issueType;
  final ReflectionSeverity severity;
  final String description;
  final String affectedGoal;
  final String suggestedFix;
  final String? toolHint;
  final String? knowledgeQuery;
  final String? plannerGoal;

  ReflectionIssue({
    required this.issueType,
    required this.severity,
    required this.description,
    required this.affectedGoal,
    required this.suggestedFix,
    this.toolHint,
    this.knowledgeQuery,
    this.plannerGoal,
  });

  Map<String, dynamic> toMap() {
    return {
      'issueType': issueType,
      'severity': severity.name,
      'description': description,
      'affectedGoal': affectedGoal,
      'suggestedFix': suggestedFix,
      'toolHint': toolHint,
      'knowledgeQuery': knowledgeQuery,
      'plannerGoal': plannerGoal,
    };
  }

  factory ReflectionIssue.fromMap(Map<String, dynamic> map) {
    return ReflectionIssue(
      issueType: map['issueType'] ?? 'Unknown',
      severity: ReflectionSeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => ReflectionSeverity.low,
      ),
      description: map['description'] ?? '',
      affectedGoal: map['affectedGoal'] ?? '',
      suggestedFix: map['suggestedFix'] ?? '',
      toolHint: map['toolHint']?.toString(),
      knowledgeQuery: map['knowledgeQuery']?.toString(),
      plannerGoal: map['plannerGoal']?.toString(),
    );
  }
}

class VerificationScore {
  final double goalScore;
  final double constraintScore;
  final double knowledgeScore;
  final double toolCoverageScore;
  final double recommendationScore;
  final double memoryScore;
  final double overallScore;

  VerificationScore({
    this.goalScore = 1.0,
    this.constraintScore = 1.0,
    this.knowledgeScore = 1.0,
    this.toolCoverageScore = 1.0,
    this.recommendationScore = 1.0,
    this.memoryScore = 1.0,
    this.overallScore = 1.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'goalScore': goalScore,
      'constraintScore': constraintScore,
      'knowledgeScore': knowledgeScore,
      'toolCoverageScore': toolCoverageScore,
      'recommendationScore': recommendationScore,
      'memoryScore': memoryScore,
      'overallScore': overallScore,
    };
  }

  factory VerificationScore.fromMap(Map<String, dynamic> map) {
    return VerificationScore(
      goalScore: (map['goalScore'] ?? 1.0).toDouble(),
      constraintScore: (map['constraintScore'] ?? 1.0).toDouble(),
      knowledgeScore: (map['knowledgeScore'] ?? 1.0).toDouble(),
      toolCoverageScore: (map['toolCoverageScore'] ?? 1.0).toDouble(),
      recommendationScore: (map['recommendationScore'] ?? 1.0).toDouble(),
      memoryScore: (map['memoryScore'] ?? 1.0).toDouble(),
      overallScore: (map['overallScore'] ?? 1.0).toDouble(),
    );
  }
}

class ReflectionResult {
  final bool isComplete;
  final ReflectionMode reflectionMode;
  final double plannerConfidence;
  final double reflectionConfidence;
  final VerificationScore verificationScore;
  final List<ReflectionIssue> issues;
  final ReflectionAction recommendedAction;
  final String stopReason;
  final List<String> satisfiedGoals;
  final List<String> missingGoals;
  final List<String> violatedConstraints;
  final List<String> contradictions;

  ReflectionResult({
    required this.isComplete,
    required this.reflectionMode,
    required this.plannerConfidence,
    required this.reflectionConfidence,
    required this.verificationScore,
    this.issues = const [],
    this.recommendedAction = ReflectionAction.continuePlanning,
    this.stopReason = '',
    this.satisfiedGoals = const [],
    this.missingGoals = const [],
    this.violatedConstraints = const [],
    this.contradictions = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'isComplete': isComplete,
      'reflectionMode': reflectionMode.name,
      'plannerConfidence': plannerConfidence,
      'reflectionConfidence': reflectionConfidence,
      'verificationScore': verificationScore.toMap(),
      'issues': issues.map((i) => i.toMap()).toList(),
      'recommendedAction': recommendedAction.name,
      'stopReason': stopReason,
      'satisfiedGoals': satisfiedGoals,
      'missingGoals': missingGoals,
      'violatedConstraints': violatedConstraints,
      'contradictions': contradictions,
    };
  }

  factory ReflectionResult.fromMap(Map<String, dynamic> map) {
    return ReflectionResult(
      isComplete: map['isComplete'] ?? false,
      reflectionMode: ReflectionMode.values.firstWhere(
        (e) => e.name == map['reflectionMode'],
        orElse: () => ReflectionMode.iterative,
      ),
      plannerConfidence: (map['plannerConfidence'] ?? 1.0).toDouble(),
      reflectionConfidence: (map['reflectionConfidence'] ?? 1.0).toDouble(),
      verificationScore: map['verificationScore'] != null 
          ? VerificationScore.fromMap(map['verificationScore']) 
          : VerificationScore(),
      issues: (map['issues'] as List?)?.map((i) => ReflectionIssue.fromMap(i)).toList() ?? [],
      recommendedAction: ReflectionAction.values.firstWhere(
        (e) => e.name == map['recommendedAction'],
        orElse: () => ReflectionAction.continuePlanning,
      ),
      stopReason: map['stopReason'] ?? '',
      satisfiedGoals: List<String>.from(map['satisfiedGoals'] ?? []),
      missingGoals: List<String>.from(map['missingGoals'] ?? []),
      violatedConstraints: List<String>.from(map['violatedConstraints'] ?? []),
      contradictions: List<String>.from(map['contradictions'] ?? []),
    );
  }
}

class ReflectionGoal {
  final String objective;

  ReflectionGoal(this.objective);
}

class ReflectionConfig {
  final int maximumReflectionCycles;
  final double minimumConfidence;
  final bool allowAutoRepair;
  final bool verifyKnowledgeConsistency;
  final bool verifyToolCoverage;
  final bool verifyRecommendations;
  final bool verifyMemory;
  final bool verifyConstraints;

  ReflectionConfig({
    this.maximumReflectionCycles = 2,
    this.minimumConfidence = 0.70,
    this.allowAutoRepair = true,
    this.verifyKnowledgeConsistency = true,
    this.verifyToolCoverage = true,
    this.verifyRecommendations = true,
    this.verifyMemory = true,
    this.verifyConstraints = true,
  });
}

enum AgentCapability {
  booking,
  knowledge,
  recommendation,
  complaint,
  analytics,
  memory,
  planning,
  reflection
}

class AgentTask {
  final String taskId;
  final AgentCapability targetAgent;
  final String objective;
  final String priority; // 'high', 'medium', 'low'
  final Map<String, dynamic> requiredInputs;
  final List<String> expectedOutputs;
  String status; // 'pending', 'running', 'completed', 'failed'

  AgentTask({
    required this.taskId,
    required this.targetAgent,
    required this.objective,
    this.priority = 'medium',
    this.requiredInputs = const {},
    this.expectedOutputs = const [],
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'targetAgent': targetAgent.name,
      'objective': objective,
      'priority': priority,
      'requiredInputs': requiredInputs,
      'expectedOutputs': expectedOutputs,
      'status': status,
    };
  }

  factory AgentTask.fromMap(Map<String, dynamic> map) {
    return AgentTask(
      taskId: map['taskId'] ?? '',
      targetAgent: AgentCapability.values.firstWhere(
        (e) => e.name == map['targetAgent'],
        orElse: () => AgentCapability.planning,
      ),
      objective: map['objective'] ?? '',
      priority: map['priority'] ?? 'medium',
      requiredInputs: Map<String, dynamic>.from(map['requiredInputs'] ?? {}),
      expectedOutputs: List<String>.from(map['expectedOutputs'] ?? []),
      status: map['status'] ?? 'pending',
    );
  }
}

class AgentResult {
  final String taskId;
  final String agentName;
  final bool success;
  final double confidence;
  final Map<String, dynamic> outputs;
  final List<String> observations;
  final Duration executionTime;

  AgentResult({
    required this.taskId,
    required this.agentName,
    required this.success,
    required this.confidence,
    required this.outputs,
    required this.observations,
    required this.executionTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'agentName': agentName,
      'success': success,
      'confidence': confidence,
      'outputs': outputs,
      'observations': observations,
      'executionTimeMs': executionTime.inMilliseconds,
    };
  }

  factory AgentResult.fromMap(Map<String, dynamic> map) {
    return AgentResult(
      taskId: map['taskId'] ?? '',
      agentName: map['agentName'] ?? '',
      success: map['success'] ?? false,
      confidence: (map['confidence'] ?? 1.0).toDouble(),
      outputs: Map<String, dynamic>.from(map['outputs'] ?? {}),
      observations: List<String>.from(map['observations'] ?? []),
      executionTime: Duration(milliseconds: map['executionTimeMs'] ?? 0),
    );
  }
}

class AgentMessage {
  final String sender;
  final String receiver;
  final String messageType;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  AgentMessage({
    required this.sender,
    required this.receiver,
    required this.messageType,
    required this.payload,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'receiver': receiver,
      'messageType': messageType,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AgentMessage.fromMap(Map<String, dynamic> map) {
    return AgentMessage(
      sender: map['sender'] ?? '',
      receiver: map['receiver'] ?? '',
      messageType: map['messageType'] ?? '',
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class CollaborationPlan {
  final String originalRequest;
  final List<AgentTask> tasks;
  final String executionStrategy;
  final List<String> dependencies;
  final String estimatedComplexity;

  CollaborationPlan({
    required this.originalRequest,
    required this.tasks,
    required this.executionStrategy,
    required this.dependencies,
    required this.estimatedComplexity,
  });

  Map<String, dynamic> toMap() {
    return {
      'originalRequest': originalRequest,
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'executionStrategy': executionStrategy,
      'dependencies': dependencies,
      'estimatedComplexity': estimatedComplexity,
    };
  }

  factory CollaborationPlan.fromMap(Map<String, dynamic> map) {
    return CollaborationPlan(
      originalRequest: map['originalRequest'] ?? '',
      tasks: (map['tasks'] as List?)?.map((t) => AgentTask.fromMap(Map<String, dynamic>.from(t))).toList() ?? [],
      executionStrategy: map['executionStrategy'] ?? '',
      dependencies: List<String>.from(map['dependencies'] ?? []),
      estimatedComplexity: map['estimatedComplexity'] ?? '',
    );
  }
}

class CollaborationState {
  final List<AgentTask> activeTasks;
  final List<AgentTask> completedTasks;
  final List<AgentTask> failedTasks;
  final Map<String, AgentResult> agentResults;
  final WorkingMemory mergedWorkingMemory;
  final List<AgentMessage> collaborationHistory;

  CollaborationState({
    required this.activeTasks,
    required this.completedTasks,
    required this.failedTasks,
    required this.agentResults,
    required this.mergedWorkingMemory,
    required this.collaborationHistory,
  });

  Map<String, dynamic> toMap() {
    return {
      'activeTasks': activeTasks.map((t) => t.toMap()).toList(),
      'completedTasks': completedTasks.map((t) => t.toMap()).toList(),
      'failedTasks': failedTasks.map((t) => t.toMap()).toList(),
      'agentResults': agentResults.map((k, v) => MapEntry(k, v.toMap())),
      'mergedWorkingMemory': mergedWorkingMemory.toMap(),
      'collaborationHistory': collaborationHistory.map((h) => h.toMap()).toList(),
    };
  }

  factory CollaborationState.fromMap(Map<String, dynamic> map) {
    final resultsMap = <String, AgentResult>{};
    if (map['agentResults'] != null) {
      (map['agentResults'] as Map).forEach((k, v) {
        resultsMap[k.toString()] = AgentResult.fromMap(Map<String, dynamic>.from(v));
      });
    }

    return CollaborationState(
      activeTasks: (map['activeTasks'] as List?)?.map((t) => AgentTask.fromMap(Map<String, dynamic>.from(t))).toList() ?? [],
      completedTasks: (map['completedTasks'] as List?)?.map((t) => AgentTask.fromMap(Map<String, dynamic>.from(t))).toList() ?? [],
      failedTasks: (map['failedTasks'] as List?)?.map((t) => AgentTask.fromMap(Map<String, dynamic>.from(t))).toList() ?? [],
      agentResults: resultsMap,
      mergedWorkingMemory: WorkingMemory.fromMap(map['mergedWorkingMemory'] ?? {}),
      collaborationHistory: (map['collaborationHistory'] as List?)?.map((h) => AgentMessage.fromMap(Map<String, dynamic>.from(h))).toList() ?? [],
    );
  }
}



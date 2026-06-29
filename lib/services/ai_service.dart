import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/user_model.dart';
import 'ai/ai_types.dart';
import 'ai/tool_executor.dart';
import 'ai/agents/response_generator.dart';
import 'ai/memory_manager.dart';
import 'ai/memory_summarizer.dart';
import 'ai/knowledge_manager.dart';
import 'ai/agent_registry.dart';
import 'ai/agents/supervisor_agent.dart';
import 'ai/agents/planning_agent.dart';
import 'ai/agents/booking_agent.dart';
import 'ai/agents/knowledge_agent.dart';
import 'ai/agents/recommendation_agent.dart';
import 'ai/agents/complaint_agent.dart';
import 'ai/agents/analytics_agent.dart';
import 'ai/agents/memory_agent.dart';
import 'ai/agents/reflection_agent_specialist.dart';
import 'ai/reflection_manager.dart';
import 'progress/progress_manager.dart';
import 'progress/progress_models.dart';
import 'progress/progress_event.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

class AiService {
  // Gemini API Key
  static const String _apiKey = 'AQ.Ab8RN6J7xi3WW8-d8sEgNvbaOE-UkWzgeMcSqGby9KGI975QZg';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  GenerativeModel? _model;

  // Orchestrator & Agents
  // PlannerAgent? _planner;
  ResponseGenerator? _responseGen;
  MemoryManager? _memoryManager;
  MemorySummarizer? _memorySummarizer;
  KnowledgeManager? _knowledgeManager;
  SupervisorAgent? _supervisor;

  AiService() {
    _initModel();
    seedFirestoreCollections();
  }

  void _initModel() {
    if (_apiKey.isNotEmpty && !_apiKey.startsWith('YOUR_GEMINI_')) {
      try {
        _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
        // _planner = PlannerAgent(_callingAgent!);
        _responseGen = ResponseGenerator(_model!);
        _memoryManager = MemoryManager();
        _memorySummarizer = MemorySummarizer(_model!);
        _knowledgeManager = KnowledgeManager(_model!);

        // Multi-Agent Framework Initialization
        _supervisor = SupervisorAgent(_model!);
        
        // Specialist Registration
        final reflectionManager = ReflectionManager(_model!);
        AgentRegistry.register(MemoryAgent(memoryManager: _memoryManager!));
        AgentRegistry.register(PlanningAgent(_model!));
        AgentRegistry.register(BookingAgent(_model!));
        AgentRegistry.register(KnowledgeAgent(_model!, knowledgeManager: _knowledgeManager!));
        AgentRegistry.register(RecommendationAgent(_model!));
        AgentRegistry.register(ComplaintAgent(_model!));
        AgentRegistry.register(AnalyticsAgent(_model!));
        AgentRegistry.register(ReflectionAgentSpecialist(reflectionManager));
      } catch (_) {}
    }
  }

  Future<void> seedFirestoreCollections() async {
    await seedKnowledgeBase();
    await seedKnowledgeChunks();
    await _seedUniversities();
    await _seedCities();
    await _seedAmenities();
    await _seedComplaintCategories();
  }

  Future<void> seedKnowledgeChunks() async {
    try {
      final snap = await _db.collection('knowledge').limit(1).get();
      if (snap.docs.isEmpty) {
        final chunks = [
          {
            'documentId': 'daily_stay_refund_policy',
            'documentTitle': 'HODS Daily Booking Cancellation & Refund Policy',
            'sectionTitle': 'Refund Eligibility & Timelines',
            'category': 'policies',
            'content': 'Daily bookings (Tourist stays) cancelled more than 48 hours before check-in are eligible for a 100% refund. Cancellations made between 24 and 48 hours receive a 50% refund. Cancellations under 24 hours are non-refundable.',
            'tags': ['refund', 'daily stay', 'cancellation', 'tourist stay'],
            'keywords': ['refund', 'cancel', 'return money'],
            'importanceScore': 0.95,
            'metadata': {'category': 'policies'},
            'lastUpdated': DateTime.now().toIso8601String(),
          },
          {
            'documentId': 'monthly_stay_checkin_guide',
            'documentTitle': 'HODS Student Check-In Guidelines',
            'sectionTitle': 'Standard Monthly Check-in Requirements',
            'category': 'policies',
            'content': 'For monthly student stays: \n1. Bring copy of University Enrollment/Admission letter. \n2. Submit copy of CNIC/B-Form. \n3. Present signed hostel agreement. Check-in hours are standard from 9:00 AM to 6:00 PM.',
            'tags': ['check-in', 'monthly stay', 'enrollment', 'CNIC'],
            'keywords': ['checkin', 'documents', 'arrival'],
            'importanceScore': 0.9,
            'metadata': {'category': 'policies'},
            'lastUpdated': DateTime.now().toIso8601String(),
          },
          {
            'documentId': 'roommate_lifestyle_rules',
            'documentTitle': 'HODS Roommate Matching Guidelines',
            'sectionTitle': 'Lifestyle Compatibilities & Cleaning Rules',
            'category': 'hostel_rules',
            'content': 'To maintain roommate matches, students must follow the code of conduct: \n- Maintain standard study silence hours from 8:00 PM to 11:00 PM. \n- Clean personal desk space weekly. \n- Mutual consent required for guests.',
            'tags': ['roommate', 'rules', 'silence hours', 'cleaning'],
            'keywords': ['roommate', 'conduct', 'quiet hours'],
            'importanceScore': 0.85,
            'metadata': {'category': 'hostel_rules'},
            'lastUpdated': DateTime.now().toIso8601String(),
          },
          {
            'documentId': 'complaint_resolution_procedures',
            'documentTitle': 'HODS Complaint Lodging Procedures',
            'sectionTitle': 'Resolution Escalations & Timelines',
            'category': 'complaints',
            'content': 'Once logged in the HODS dashboard: \n- Urgent complaints (electricity/water breakdown) must be acknowledged by the owner within 12 hours and resolved in 24 hours. \n- Non-urgent issues (wifi speed, minor maintenance) are resolved within 3-5 days.',
            'tags': ['complaint', 'timeline', 'escalation', 'maintenance'],
            'keywords': ['complaint', 'repair time', 'water breakdown'],
            'importanceScore': 0.8,
            'metadata': {'category': 'complaints'},
            'lastUpdated': DateTime.now().toIso8601String(),
          },
        ];
        for (final c in chunks) {
          await _db.collection('knowledge').add(c);
        }
      }
    } catch (_) {}
  }

  Future<void> _seedUniversities() async {
    try {
      final snap = await _db.collection('universities').limit(1).get();
      if (snap.docs.isEmpty) {
        final univs = [
          {
            'name': 'National University of Sciences and Technology',
            'aliases': ['nust', 'national university of sciences and technology'],
            'latitude': 33.6423,
            'longitude': 72.9904,
            'city': 'Islamabad'
          },
          {
            'name': 'FAST NUCES',
            'aliases': ['fast', 'fast-nuces', 'nuces', 'fast university'],
            'latitude': 33.6416,
            'longitude': 73.0234,
            'city': 'Islamabad'
          },
          {
            'name': 'COMSATS University',
            'aliases': ['comsats', 'comsat', 'cui'],
            'latitude': 33.6518,
            'longitude': 73.1565,
            'city': 'Islamabad'
          },
          {
            'name': 'Quaid-i-Azam University',
            'aliases': ['qau', 'quaid-i-azam university', 'quaid e azam'],
            'latitude': 33.7483,
            'longitude': 73.1360,
            'city': 'Islamabad'
          },
          {
            'name': 'GIK Institute',
            'aliases': ['giki', 'gik', 'gulam ishaq khan'],
            'latitude': 34.0205,
            'longitude': 72.6397,
            'city': 'Topi'
          },
          {
            'name': 'Lahore University of Management Sciences',
            'aliases': ['lums', 'lahore university of management sciences'],
            'latitude': 31.4705,
            'longitude': 74.4089,
            'city': 'Lahore'
          },
          {
            'name': 'University of Management and Technology',
            'aliases': ['umt', 'university of management and technology'],
            'latitude': 31.4504,
            'longitude': 74.2962,
            'city': 'Lahore'
          },
          {
            'name': 'University of Engineering and Technology',
            'aliases': ['uet', 'university of engineering and technology', 'uet lahore'],
            'latitude': 31.5796,
            'longitude': 74.3563,
            'city': 'Lahore'
          },
          {
            'name': 'Iqra University',
            'aliases': ['iqra', 'iqra university'],
            'latitude': 33.6844,
            'longitude': 73.0479,
            'city': 'Islamabad'
          }
        ];
        for (final u in univs) {
          await _db.collection('universities').add(u);
        }
      }
    } catch (_) {}
  }

  Future<void> _seedCities() async {
    try {
      final snap = await _db.collection('cities').limit(1).get();
      if (snap.docs.isEmpty) {
        final citiesList = [
          {
            'name': 'Karachi',
            'aliases': ['karachi', 'khi'],
            'latitude': 24.8607,
            'longitude': 67.0011
          },
          {
            'name': 'Lahore',
            'aliases': ['lahore', 'lhr'],
            'latitude': 31.5204,
            'longitude': 74.3587
          },
          {
            'name': 'Islamabad',
            'aliases': ['islamabad', 'isb'],
            'latitude': 33.6844,
            'longitude': 73.0479
          },
          {
            'name': 'Rawalpindi',
            'aliases': ['rawalpindi', 'pindi', 'rwp'],
            'latitude': 33.5984,
            'longitude': 73.0441
          },
          {
            'name': 'Faisalabad',
            'aliases': ['faisalabad', 'fsd'],
            'latitude': 31.4504,
            'longitude': 73.1350
          },
          {
            'name': 'Multan',
            'aliases': ['multan', 'mux'],
            'latitude': 30.1575,
            'longitude': 71.5249
          },
          {
            'name': 'Peshawar',
            'aliases': ['peshawar', 'pew'],
            'latitude': 34.0151,
            'longitude': 71.5249
          },
          {
            'name': 'Quetta',
            'aliases': ['quetta', 'ueti'],
            'latitude': 30.1798,
            'longitude': 66.9750
          },
          {
            'name': 'Sialkot',
            'aliases': ['sialkot', 'skt'],
            'latitude': 32.4945,
            'longitude': 74.5229
          }
        ];
        for (final c in citiesList) {
          await _db.collection('cities').add(c);
        }
      }
    } catch (_) {}
  }

  Future<void> _seedAmenities() async {
    try {
      final snap = await _db.collection('amenities').limit(1).get();
      if (snap.docs.isEmpty) {
        final amenitiesList = [
          {'name': 'WiFi', 'icon': 'wifi'},
          {'name': 'AC', 'icon': 'ac_unit'},
          {'name': 'Meals', 'icon': 'restaurant'},
          {'name': 'Laundry', 'icon': 'local_laundry_service'},
          {'name': 'Generator', 'icon': 'electric_bolt'},
          {'name': 'CCTV', 'icon': 'videocam'},
          {'name': 'Study Room', 'icon': 'menu_book'},
          {'name': 'Gym', 'icon': 'fitness_center'},
          {'name': 'Parking', 'icon': 'local_parking'},
          {'name': 'Water Cooler', 'icon': 'water_drop'},
          {'name': 'Attached Bathroom', 'icon': 'bathtub'},
          {'name': 'Geyser', 'icon': 'hot_tub'}
        ];
        for (final a in amenitiesList) {
          await _db.collection('amenities').add(a);
        }
      }
    } catch (_) {}
  }

  Future<void> _seedComplaintCategories() async {
    try {
      final snap = await _db.collection('complaint_categories').limit(1).get();
      if (snap.docs.isEmpty) {
        final cats = [
          {'name': 'Electricity', 'icon': 'bolt', 'color': 'amber'},
          {'name': 'Water', 'icon': 'water_drop', 'color': 'blue'},
          {'name': 'Internet', 'icon': 'wifi', 'color': 'purple'},
          {'name': 'Mess', 'icon': 'restaurant', 'color': 'orange'},
          {'name': 'Security', 'icon': 'security', 'color': 'red'},
          {'name': 'Maintenance', 'icon': 'build_circle', 'color': 'green'},
          {'name': 'Other', 'icon': 'assignment_outlined', 'color': 'grey'}
        ];
        for (final c in cats) {
          await _db.collection('complaint_categories').add(c);
        }
      }
    } catch (_) {}
  }

  Future<void> seedKnowledgeBase() async {
    try {
      final snap = await _db.collection('knowledge_base').limit(1).get();
      if (snap.docs.isEmpty) {
        final faqs = [
          {
            'question': 'how to book a hostel',
            'answer': 'To book a hostel in HODS: \n1. Browse or search for hostels from the Search screen. \n2. Select your desired hostel to view its profile details. \n3. Tap the primary "Book Room" button. \n4. Choose your stay type (Monthly or Daily stay) and pick check-in dates. \n5. Tap "Book Room" to submit the request to the hostel owner for verification.',
            'keywords': ['book', 'booking', 'reserve', 'rent room']
          },
          {
            'question': 'what is daily booking stay',
            'answer': 'Daily Booking Mode (Tourist Stay) allows you to rent a hostel room on a short-term, per-day basis starting at PKR 1200/day. This is ideal for short visits, parent stays, campus tours, or exams.',
            'keywords': ['daily', 'tourist', 'day', 'short stay', 'per day']
          },
          {
            'question': 'how roommate matching works',
            'answer': 'HODS Roommate Matchmaker compares your lifestyle profile characteristics (Budget, University, Gender, Study habits, Sleep times, Smoking habits, Cleanliness level) and ranks them using a dynamic matching score (0-100%). \n\nGo to dashboard ➔ select Roommates action ➔ complete Roommate Setup card ➔ view matched profiles instantly.',
            'keywords': ['roommate', 'matching', 'room mate', 'find roommate']
          },
          {
            'question': 'how to trace hostel location directions',
            'answer': 'HODS provides an advanced Proximity Radar Map! When viewing hostel details, scroll to the "Location & Surrounding Radar" card to see metro stations, dining markaz, and campus distances, then tap "Trace Location on Google Maps" to launch driving GPS turn-by-turn navigation.',
            'keywords': ['maps', 'directions', 'trace', 'location', 'radar', 'where is']
          },
          {
            'question': 'how to file a complaint',
            'answer': 'To file a complaint in HODS:\n1. Tap "Complaints" from dashboard Quick Actions.\n2. Tap "File Complaint".\n3. Select your active hostel, choose a category (electricity, water, mess, wifi, maintenance, etc.), write a title and description, and submit. The owner will be notified to start progress.',
            'keywords': ['complaint', 'report', 'issue', 'broken', 'repair']
          }
        ];
        for (final faq in faqs) {
          await _db.collection('knowledge_base').add(faq);
        }
      }
    } catch (_) {}
  }

  Future<String> _queryKnowledgeBase(String message) async {
    try {
      final queryStr = message.toLowerCase().trim();
      final snap = await _db.collection('knowledge_base').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final question = (data['question'] ?? '').toString().toLowerCase();
        final answer = (data['answer'] ?? '').toString();
        final keywords = List<String>.from(data['keywords'] ?? []);

        if (question.isNotEmpty && (queryStr.contains(question) || question.contains(queryStr))) {
          return answer;
        }

        for (final keyword in keywords) {
          if (keyword.isNotEmpty && queryStr.contains(keyword.toLowerCase())) {
            return answer;
          }
        }
      }
    } catch (_) {}
    return '';
  }

  Future<String> sendMessage(
    String message,
    String userId,
    UserRole role, {
    ProgressManager? progressManager,
  }) async {
    if (_model == null || _supervisor == null || _responseGen == null || _memoryManager == null || _memorySummarizer == null || _knowledgeManager == null) {
      final context = await _buildOfflineContext(userId, role, message);
      return await _generateOfflineResponse(message, role, context);
    }

    try {
      // 0. Load long-term memory context and build WorkingMemory facts
      final memoryContext = await _memoryManager!.retrieveMemoryContext(userId, MemoryRetrievalConfig());
      final initialWorkingMemory = _memoryManager!.mergeToWorkingMemory(memoryContext, WorkingMemory());

      // 1. Delegate plan execution to SupervisorAgent
      final supervisor = SupervisorAgent(_model!, progressManager: progressManager);
      final ExecutionState executionState = await supervisor.collaborate(
        message,
        userId,
        role,
        initialWorkingMemory: initialWorkingMemory,
      );

      progressManager?.emit(ProgressEvent(
        taskId: 'response_generator',
        stage: ProgressStage.generatingAnswer,
        status: ProgressStatus.started,
        title: 'Response Generator',
        message: 'Preparing your response...',
        agentName: 'ResponseGenerator',
        timestamp: DateTime.now(),
      ));

      // 2. Generate final response from response generator
      const conversationSummary = ''; // Placeholder for future memory integration
      final responseText = await _responseGen!.generate(
        message,
        role,
        conversationSummary,
        executionState,
        memoryContext,
        executionState.knowledgeContext,
        executionState.recommendationContext,
      );

      progressManager?.emit(ProgressEvent(
        taskId: 'response_generator',
        stage: ProgressStage.generatingAnswer,
        status: ProgressStatus.completed,
        title: 'Response Generator',
        message: 'Response ready.',
        agentName: 'ResponseGenerator',
        timestamp: DateTime.now(),
      ));

      progressManager?.emit(ProgressEvent(
        taskId: 'session',
        stage: ProgressStage.completed,
        status: ProgressStatus.completed,
        title: 'Completed',
        message: 'Response Ready',
        agentName: 'AiService',
        timestamp: DateTime.now(),
      ));

      // 3. Asynchronously summarize the conversation and update memory
      _memorySummarizer!.summarize(message, executionState).then((summaryUpdate) {
        _memoryManager!.saveMemoryUpdate(userId, summaryUpdate, 'MemorySummarizer');
      }).catchError((_) {});

      return responseText;
    } catch (e) {
      progressManager?.emit(ProgressEvent(
        taskId: 'session',
        stage: ProgressStage.error,
        status: ProgressStatus.failed,
        severity: ProgressSeverity.error,
        title: 'Error',
        message: 'Processing interrupted: ${e.toString()}',
        agentName: 'AiService',
        timestamp: DateTime.now(),
      ));

      final context = await _buildOfflineContext(userId, role, message);
      return await _generateOfflineResponse(message, role, context);
    }
  }

  Future<Map<String, dynamic>> _buildOfflineContext(String userId, UserRole role, String message) async {
    final context = <String, dynamic>{};
    try {
      final executor = ToolExecutor();
      final rankedResult = await executor.execute(
        'searchHostels',
        {
          'budget': 25000.0,
          'stayType': message.toLowerCase().contains('daily') ? 'daily' : 'monthly'
        },
        userId,
        role,
      );
      context['recommendedHostels'] = rankedResult.data['results'] ?? [];
      
      final bookingsResult = await executor.execute('getBookings', {}, userId, role);
      context['bookings'] = bookingsResult.data['bookings'] ?? [];
      
      final complaintsResult = await executor.execute('getComplaints', {}, userId, role);
      context['complaints'] = complaintsResult.data['complaints'] ?? [];
      
      if (role == UserRole.owner) {
        final ownerResult = await executor.execute('ownerAnalytics', {}, userId, role);
        context['ownerBusinessStats'] = ownerResult.data;
      }
      
      if (role == UserRole.admin) {
        final adminResult = await executor.execute('adminAnalytics', {}, userId, role);
        context['systemStats'] = adminResult.data;
      }
    } catch (_) {}
    return context;
  }

  Future<String> _generateOfflineResponse(
    String message,
    UserRole role,
    Map<String, dynamic> contextData,
  ) async {
    final faq = await _queryKnowledgeBase(message);
    if (faq.isNotEmpty) {
      return "$faq\n\n*(Offline Mode Active)*";
    }

    final buffer = StringBuffer();
    final recs = contextData['recommendedHostels'] as List<dynamic>?;
    if (recs != null && recs.isNotEmpty) {
      buffer.writeln("🔍 Recommended Hostels (Offline Match):");
      for (int i = 0; i < recs.length; i++) {
        final r = recs[i];
        buffer.writeln("${i + 1}. ${r['name']} (${r['city']})");
        buffer.writeln("   💰 Price: PKR ${r['pricePerMonth'].toInt()}/mo");
        buffer.writeln("   📍 Distance: ${r['distance'].toStringAsFixed(1)} km");
        buffer.writeln("   ⭐ Rating: ${r['rating']}");
        buffer.writeln("   🎯 Compatibility Score: ${r['score'].toStringAsFixed(0)}%");
        buffer.writeln("");
      }
      return buffer.toString();
    }

    final bookings = contextData['bookings'] as List<dynamic>?;
    if (bookings != null && bookings.isNotEmpty) {
      buffer.writeln("📅 Bookings Status (Offline View):");
      for (final b in bookings) {
        buffer.writeln("• ${b['hostelName']} (Room ${b['roomNumber']})");
        buffer.writeln("  Status: ${b['status'].toString().toUpperCase()}");
        buffer.writeln("  Amount: PKR ${b['totalAmount'].toInt()}");
        buffer.writeln("");
      }
      return buffer.toString();
    }

    final complaints = contextData['complaints'] as List<dynamic>?;
    if (complaints != null && complaints.isNotEmpty) {
      buffer.writeln("⚠️ Filed Complaints (Offline View):");
      for (final c in complaints) {
        buffer.writeln("• [${c['category']}] ${c['title']}");
        buffer.writeln("  Status: ${c['status'].toString().toUpperCase()}");
        buffer.writeln("  Details: ${c['description']}");
        buffer.writeln("");
      }
      return buffer.toString();
    }

    if (role == UserRole.owner) {
      final stats = contextData['ownerBusinessStats'];
      if (stats != null) {
        buffer.writeln("📈 Owner Business Analytics (Offline View):");
        buffer.writeln("• Hostels Owned: ${stats['hostelsOwned']}");
        buffer.writeln("• Total Revenue: PKR ${stats['totalRevenue'].toStringAsFixed(0)}");
        buffer.writeln("• Active Bookings: ${stats['activeBookings']}");
        buffer.writeln("• Pending Approvals: ${stats['pendingBookings']}");
        buffer.writeln("• Beds Booked: ${stats['totalBedsBooked']}");
        buffer.writeln("• Filed Complaints: ${stats['totalComplaints']} (${stats['pendingComplaints']} pending)");
        return buffer.toString();
      }
    }

    if (role == UserRole.admin) {
      final stats = contextData['systemStats'];
      if (stats != null) {
        buffer.writeln("📊 Admin System Analytics (Offline View):");
        buffer.writeln("• Total Platform Users: ${stats['totalUsers']}");
        buffer.writeln("• Total Platform Hostels: ${stats['totalHostels']}");
        buffer.writeln("• Total Bookings Filed: ${stats['totalBookings']}");
        return buffer.toString();
      }
    }

    return "Hello! I am your HODS AI Assistant. Under offline/fallback mode, I can still parse search requests. \n\nTry asking about: \n- 'hostel recommendations near FAST' \n- 'find compatible roommates' \n- 'my booking status'";
  }

  void resetConversation() {
    _initModel();
  }
}

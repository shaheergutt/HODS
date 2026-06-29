// ignore_for_file: subtype_of_sealed_class
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hods/models/complaint_model.dart';
import 'package:hods/repositories/complaint_repository.dart';
import 'package:hods/services/complaints/complaint_service.dart';
import 'package:hods/services/notification_service.dart';

// ── TEST FAKES ───────────────────────────────────────────────────

class FakeUser implements User {
  @override
  final String uid;
  FakeUser(this.uid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseAuth implements FirebaseAuth {
  User? _currentUser;
  FakeFirebaseAuth({User? currentUser}) : _currentUser = currentUser;

  @override
  User? get currentUser => _currentUser;

  void setCurrentUser(User? user) {
    _currentUser = user;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeComplaintRepository implements ComplaintRepository {
  final Map<String, ComplaintModel> complaints = {};

  @override
  Future<ComplaintModel?> getComplaint(String id) async {
    return complaints[id];
  }

  @override
  Future<String> createComplaint(ComplaintModel complaint) async {
    final id = complaint.id.isEmpty ? 'mock-id' : complaint.id;
    complaints[id] = ComplaintModel(
      id: id,
      studentId: complaint.studentId,
      studentName: complaint.studentName,
      hostelId: complaint.hostelId,
      hostelName: complaint.hostelName,
      hostelOwnerId: complaint.hostelOwnerId,
      bookingId: complaint.bookingId,
      title: complaint.title,
      description: complaint.description,
      category: complaint.category,
      priority: complaint.priority,
      status: complaint.status,
      rating: complaint.rating,
      ownerReply: complaint.ownerReply,
      studentResponse: complaint.studentResponse,
      attachments: complaint.attachments,
      timeline: complaint.timeline,
      createdAt: complaint.createdAt,
      updatedAt: complaint.updatedAt,
      resolvedAt: complaint.resolvedAt,
      closedAt: complaint.closedAt,
    );
    return id;
  }

  @override
  Future<void> updateStatusAndLogTimeline(
    String id,
    ComplaintStatus status,
    TimelineEntry entry, {
    Map<String, dynamic> extraFields = const {},
  }) async {
    final complaint = complaints[id];
    if (complaint != null) {
      complaints[id] = complaint.copyWith(
        status: status,
        timeline: [...complaint.timeline, entry],
      );
    }
  }

  @override
  Future<void> logTimelineEvent(String id, TimelineEntry entry) async {
    final complaint = complaints[id];
    if (complaint != null) {
      complaints[id] = complaint.copyWith(
        timeline: [...complaint.timeline, entry],
      );
    }
  }

  @override
  Future<void> deleteComplaint(String id) async {
    complaints.remove(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final bool _exists;
  final Map<String, dynamic>? _data;
  FakeDocumentSnapshot(this._exists, this._data);

  @override
  bool get exists => _exists;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocumentReference implements DocumentReference<Map<String, dynamic>> {
  final DocumentSnapshot<Map<String, dynamic>> _snapshot;
  FakeDocumentReference(this._snapshot);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    return _snapshot;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCollectionReference implements CollectionReference<Map<String, dynamic>> {
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _docs;
  FakeCollectionReference(this._docs);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final snap = _docs[path] ?? FakeDocumentSnapshot(false, null);
    return FakeDocumentReference(snap);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseFirestore implements FirebaseFirestore {
  final Map<String, FakeCollectionReference> _collections = {};

  void setCollection(String path, FakeCollectionReference ref) {
    _collections[path] = ref;
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _collections[path] ?? FakeCollectionReference({});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNotificationService implements NotificationService {
  @override
  Future<void> sendNotification({
    required String title,
    required String body,
    required String userId,
    String type = '',
  }) async {
    // no-op
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── TEST SUITE ───────────────────────────────────────────────────

void main() {
  group('ComplaintService Authorization Tests', () {
    late FakeFirebaseAuth mockAuth;
    late FakeFirebaseFirestore mockFirestore;
    late FakeComplaintRepository mockRepository;
    late ComplaintService service;

    setUp(() {
      mockAuth = FakeFirebaseAuth();
      mockFirestore = FakeFirebaseFirestore();
      mockRepository = FakeComplaintRepository();
      service = ComplaintService(
        mockRepository,
        db: mockFirestore,
        auth: mockAuth,
        notificationService: FakeNotificationService(),
      );

      // Seed a default complaint
      mockRepository.complaints['complaint-1'] = ComplaintModel(
        id: 'complaint-1',
        studentId: 'student-123',
        studentName: 'Student Alice',
        hostelId: 'hostel-789',
        hostelName: 'Pine Hostel',
        hostelOwnerId: 'owner-456',
        title: 'Broken fan',
        description: 'Room 303 fan does not work',
        category: 'Maintenance',
        status: ComplaintStatus.pending,
        priority: ComplaintPriority.medium,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    void logInAs(String uid, {String role = 'student'}) {
      mockAuth.setCurrentUser(FakeUser(uid));
      // Seed the users collection profile to mock roles check
      mockFirestore.setCollection(
        'users',
        FakeCollectionReference({
          uid: FakeDocumentSnapshot(true, {'role': role}),
        }),
      );
    }

    test('Throws Authentication required when no user is logged in', () async {
      expect(
        () => service.studentReply(complaintId: 'complaint-1', response: 'Hi'),
        throwsA(isException.having((e) => e.toString(), 'message', contains('Authentication required.'))),
      );
    });

    test('Throws Complaint not found if complaint does not exist', () async {
      logInAs('student-123');
      expect(
        () => service.studentReply(complaintId: 'non-existent', response: 'Hi'),
        throwsA(isException.having((e) => e.toString(), 'message', contains('Complaint not found.'))),
      );
    });

    group('Student Authorization Scenarios', () {
      test('Allows owner student to reply or resolve complaint', () async {
        logInAs('student-123');
        await expectLater(
          service.studentReply(complaintId: 'complaint-1', response: 'Still not working'),
          completes,
        );
        await expectLater(
          service.confirmResolution(complaintId: 'complaint-1', rating: 5),
          completes,
        );
      });

      test('Denies a different student to perform student actions', () async {
        logInAs('stranger-student');
        expect(
          () => service.studentReply(complaintId: 'complaint-1', response: 'Hi'),
          throwsA(isException.having((e) => e.toString(), 'message', contains('Unauthorized student operation.'))),
        );
        expect(
          () => service.confirmResolution(complaintId: 'complaint-1', rating: 4),
          throwsA(isException.having((e) => e.toString(), 'message', contains('Unauthorized student operation.'))),
        );
      });

      test('Denies student to perform owner or admin actions', () async {
        logInAs('student-123');
        expect(
          () => service.replyToComplaint(complaintId: 'complaint-1', reply: 'Resolving', newStatus: ComplaintStatus.resolved),
          throwsA(isException.having((e) => e.toString(), 'message', contains('Unauthorized owner operation.'))),
        );
        expect(
          () => service.deleteComplaint('complaint-1'),
          throwsA(isException.having((e) => e.toString(), 'message', contains('Unauthorized administrator operation.'))),
        );
      });
    });

    group('Hostel Owner Authorization Scenarios', () {
      test('Allows assigned owner to perform owner actions', () async {
        logInAs('owner-456', role: 'owner');
        await expectLater(
          service.replyToComplaint(complaintId: 'complaint-1', reply: 'Fixing tomorrow', newStatus: ComplaintStatus.inProgress),
          completes,
        );
        await expectLater(
          service.assignComplaint(complaintId: 'complaint-1', assignTo: 'Electrician John'),
          completes,
        );
        await expectLater(
          service.logOwnerViewed('complaint-1'),
          completes,
        );
      });

      test('Denies a different owner to perform owner actions', () async {
        logInAs('stranger-owner', role: 'owner');
        expect(
          () => service.replyToComplaint(complaintId: 'complaint-1', reply: 'Hi', newStatus: ComplaintStatus.resolved),
          throwsA(isException.having((e) => e.toString(), 'message', contains('Unauthorized owner operation.'))),
        );
      });

      test('Denies owner to perform student or admin actions', () async {
        logInAs('owner-456', role: 'owner');
        expect(
          () => service.studentReply(complaintId: 'complaint-1', response: 'Hi'),
          throwsA(isException.having((e) => e.toString(), 'message', contains('Unauthorized student operation.'))),
        );
        expect(
          () => service.deleteComplaint('complaint-1'),
          throwsA(isException.having((e) => e.toString(), 'message', contains('Unauthorized administrator operation.'))),
        );
      });
    });

    group('Admin Authorization Scenarios', () {
      test('Allows admin to perform admin actions on any complaint', () async {
        logInAs('admin-789', role: 'admin');
        await expectLater(
          service.forceCloseComplaint('complaint-1', 'Closed due to terms violation'),
          completes,
        );
        await expectLater(
          service.reassignComplaint('complaint-1', 'new-owner-uid', 'New Hostel Owner'),
          completes,
        );
        await expectLater(
          service.deleteComplaint('complaint-1'),
          completes,
        );
      });

      test('Denies non-admin users to perform admin actions', () async {
        logInAs('student-123', role: 'student');
        expect(
          () => service.forceCloseComplaint('complaint-1', 'test'),
          throwsA(isException.having((e) => e.toString(), 'message', contains('Unauthorized administrator operation.'))),
        );
        expect(
          () => service.deleteComplaint('complaint-1'),
          throwsA(isException.having((e) => e.toString(), 'message', contains('Unauthorized administrator operation.'))),
        );
      });
    });
  });
}

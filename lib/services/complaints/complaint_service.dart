import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/complaint_model.dart';
import '../../repositories/complaint_repository.dart';
import '../notification_service.dart';

class ComplaintService {
  final ComplaintRepository _repository;
  final NotificationService _notificationService;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ComplaintService(
    this._repository, {
    NotificationService? notificationService,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _notificationService = notificationService ?? NotificationService(),
        _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Validates that a user is currently authenticated, else throws an Exception.
  void _validateAuth() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Authentication required.');
    }
  }

  Future<ComplaintModel> _requireComplaint(String complaintId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Authentication required.');
    }
    final complaint = await _repository.getComplaint(complaintId);
    if (complaint == null) {
      throw Exception('Complaint not found.');
    }
    return complaint;
  }

  Future<ComplaintModel> _requireStudent(String complaintId) async {
    final complaint = await _requireComplaint(complaintId);
    final currentUser = _auth.currentUser!;
    if (currentUser.uid != complaint.studentId) {
      throw Exception('Unauthorized student operation.');
    }
    return complaint;
  }

  Future<ComplaintModel> _requireOwner(String complaintId) async {
    final complaint = await _requireComplaint(complaintId);
    final currentUser = _auth.currentUser!;
    if (currentUser.uid != complaint.hostelOwnerId) {
      throw Exception('Unauthorized owner operation.');
    }
    return complaint;
  }

  Future<ComplaintModel> _requireAdmin(String complaintId) async {
    final complaint = await _requireComplaint(complaintId);
    final currentUser = _auth.currentUser!;
    final userDoc = await _db.collection('users').doc(currentUser.uid).get();
    if (!userDoc.exists || userDoc.data()?['role'] != 'admin') {
      throw Exception('Unauthorized administrator operation.');
    }
    return complaint;
  }

  /// Helper to notify all administrator users.
  Future<void> _notifyAllAdmins({
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      for (final doc in snap.docs) {
        await _notificationService.sendNotification(
          title: title,
          body: body,
          userId: doc.id,
          type: type,
        );
      }
    } catch (_) {
      // In-app notifications failure shouldn't crash main operations
    }
  }

  /// Creates a new complaint, logs to timeline, and notifies owner and admins.
  Future<String> createComplaint(ComplaintModel complaint) async {
    _validateAuth();
    final currentUser = _auth.currentUser!;
    if (currentUser.uid != complaint.studentId) {
      throw Exception('Unauthorized student operation.');
    }

    final complaintId = await _repository.createComplaint(complaint);

    // 1. Notify Owner
    try {
      await _notificationService.sendNotification(
        title: 'New Complaint Submitted ⚠️',
        body: 'Hostel: ${complaint.hostelName}\nStudent: ${complaint.studentName}\nPriority: ${complaint.priorityLabel}',
        userId: complaint.hostelOwnerId,
        type: 'complaint_new',
      );
    } catch (_) {}

    // 2. Notify Admins
    await _notifyAllAdmins(
      title: 'New Complaint Submitted ⚠️',
      body: 'Hostel: ${complaint.hostelName}\nStudent: ${complaint.studentName}\nPriority: ${complaint.priorityLabel}',
      type: 'complaint_new',
    );

    return complaintId;
  }

  /// Owner Action: Replies to complaint and/or updates status.
  Future<void> replyToComplaint({
    required String complaintId,
    required String reply,
    required ComplaintStatus newStatus,
  }) async {
    final complaint = await _requireOwner(complaintId);

    final now = DateTime.now();
    final Map<String, dynamic> extraFields = {};
    String timelineDesc = 'Status updated to ${newStatus.statusLabel}';

    if (reply.isNotEmpty) {
      extraFields['ownerReply'] = reply;
      timelineDesc = 'Owner replied: "$reply"';
    }
    if (newStatus == ComplaintStatus.resolved) {
      extraFields['resolvedAt'] = Timestamp.fromDate(now);
      timelineDesc = 'Issue marked as RESOLVED by Owner. Reply: "$reply"';
    }

    final entry = TimelineEntry(
      title: reply.isNotEmpty ? 'Owner Replied' : 'Status Updated',
      actor: 'Owner',
      description: timelineDesc,
      timestamp: now,
    );

    await _repository.updateStatusAndLogTimeline(
      complaintId,
      newStatus,
      entry,
      extraFields: extraFields,
    );

    // Notifications
    try {
      if (newStatus == ComplaintStatus.resolved) {
        await _notificationService.sendNotification(
          title: 'Your complaint has been marked as resolved.',
          body: 'Is your issue resolved? Select YES to close or NO to reopen.',
          userId: complaint.studentId,
          type: 'complaint_resolved',
        );
      } else {
        if (reply.isNotEmpty) {
          await _notificationService.sendNotification(
            title: 'Owner replied to your complaint.',
            body: reply,
            userId: complaint.studentId,
            type: 'complaint_reply',
          );
        }
        if (complaint.status != newStatus) {
          await _notificationService.sendNotification(
            title: 'Complaint status updated.',
            body: 'Your complaint "${complaint.title}" is now "${newStatus.statusLabel}".',
            userId: complaint.studentId,
            type: 'complaint_status',
          );
        }
      }
    } catch (_) {}
  }

  /// Student Action: Reply to the owner when information is requested.
  Future<void> studentReply({
    required String complaintId,
    required String response,
  }) async {
    final complaint = await _requireStudent(complaintId);

    final now = DateTime.now();
    final entry = TimelineEntry(
      title: 'Student Replied',
      actor: 'Student',
      description: 'Student replied: "$response"',
      timestamp: now,
    );

    // Switch status back to inProgress if waiting for student
    final nextStatus = complaint.status == ComplaintStatus.waitingForStudent
        ? ComplaintStatus.inProgress
        : complaint.status;

    await _repository.updateStatusAndLogTimeline(
      complaintId,
      nextStatus,
      entry,
      extraFields: {'studentResponse': response},
    );

    // Notify Owner
    try {
      await _notificationService.sendNotification(
        title: 'Student Replied to Complaint',
        body: response,
        userId: complaint.hostelOwnerId,
        type: 'complaint_reply',
      );
    } catch (_) {}
  }

  /// Student Action: Confirms resolution (YES) -> closes complaint.
  Future<void> confirmResolution({
    required String complaintId,
    required int rating,
  }) async {
    final complaint = await _requireStudent(complaintId);

    final now = DateTime.now();
    final entry = TimelineEntry(
      title: 'Resolution Confirmed',
      actor: 'Student',
      description: 'Student confirmed resolution. Rating: $rating stars.',
      timestamp: now,
    );

    await _repository.updateStatusAndLogTimeline(
      complaintId,
      ComplaintStatus.closed,
      entry,
      extraFields: {
        'rating': rating,
        'closedAt': Timestamp.fromDate(now),
      },
    );

    // Notify Admins
    await _notifyAllAdmins(
      title: 'Complaint Resolution Confirmed ✅',
      body: 'Student ${complaint.studentName} confirmed resolution for "${complaint.title}".',
      type: 'complaint_closed',
    );
  }

  /// Student Action: Rejects resolution (NO) -> reopens complaint.
  Future<void> rejectResolution({
    required String complaintId,
    required String reason,
  }) async {
    final complaint = await _requireStudent(complaintId);

    final now = DateTime.now();
    final entry = TimelineEntry(
      title: 'Resolution Rejected / Reopened',
      actor: 'Student',
      description: 'Student rejected resolution. Reason: $reason',
      timestamp: now,
    );

    await _repository.updateStatusAndLogTimeline(
      complaintId,
      ComplaintStatus.reopened,
      entry,
    );

    // 1. Notify Owner
    try {
      await _notificationService.sendNotification(
        title: 'Complaint Reopened ⚠️',
        body: 'Student ${complaint.studentName} rejected resolution for "${complaint.title}".',
        userId: complaint.hostelOwnerId,
        type: 'complaint_reopened',
      );
    } catch (_) {}

    // 2. Notify Admins (Escalation)
    await _notifyAllAdmins(
      title: 'Complaint Escalated 🚨',
      body: 'Student ${complaint.studentName} reopened complaint "${complaint.title}" at ${complaint.hostelName}.',
      type: 'complaint_escalation',
    );
  }

  /// Owner Action: Assigns complaint to specific personnel.
  Future<void> assignComplaint({
    required String complaintId,
    required String assignTo,
  }) async {
    final complaint = await _requireOwner(complaintId);

    final now = DateTime.now();
    final entry = TimelineEntry(
      title: 'Complaint Assigned',
      actor: 'Owner',
      description: 'Complaint assigned to: $assignTo',
      timestamp: now,
    );

    await _repository.updateStatusAndLogTimeline(
      complaintId,
      ComplaintStatus.assigned,
      entry,
    );

    // Notify Student
    try {
      await _notificationService.sendNotification(
        title: 'Complaint Assigned',
        body: 'Your complaint "${complaint.title}" has been assigned to "$assignTo" for resolution.',
        userId: complaint.studentId,
        type: 'complaint_assigned',
      );
    } catch (_) {}
  }

  /// Student/Admin Action: Closes a complaint and submits a satisfaction rating.
  Future<void> closeComplaint(String complaintId, int rating) async {
    await confirmResolution(complaintId: complaintId, rating: rating);
  }

  /// Owner/Admin Action: Updates status (Mark In Progress, Close, etc.) manually.
  Future<void> updateComplaintStatus(String id, ComplaintStatus status) async {
    _validateAuth();
    final currentUser = _auth.currentUser!;

    // Allow if user is the hostel owner OR if user is an admin.
    final complaint = await _requireComplaint(id);
    final isOwner = currentUser.uid == complaint.hostelOwnerId;

    if (!isOwner) {
      // Check if admin
      final userDoc = await _db.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists || userDoc.data()?['role'] != 'admin') {
        throw Exception('Unauthorized: only the hostel owner or an admin can update this complaint.');
      }
    }

    final now = DateTime.now();
    final entry = TimelineEntry(
      title: 'Status Updated',
      actor: isOwner ? 'Owner' : 'Admin',
      description: 'Complaint status changed to: ${status.statusLabel}',
      timestamp: now,
    );

    final Map<String, dynamic> extraFields = {};
    if (status == ComplaintStatus.closed) {
      extraFields['closedAt'] = Timestamp.fromDate(now);
    } else if (status == ComplaintStatus.resolved) {
      extraFields['resolvedAt'] = Timestamp.fromDate(now);
    }

    await _repository.updateStatusAndLogTimeline(
      id,
      status,
      entry,
      extraFields: extraFields,
    );
  }

  /// Logger helper: records "Owner Viewed" on first detail load
  Future<void> logOwnerViewed(String id) async {
    try {
      // Bail out early if user is not authenticated (e.g. auth state transitioning)
      if (_auth.currentUser == null) return;
      final complaint = await _requireOwner(id);

      // Check if "Owner Viewed" is already in timeline
      final hasViewed = complaint.timeline.any((e) => e.title == 'Owner Viewed');
      if (!hasViewed) {
        final now = DateTime.now();
        final entry = TimelineEntry(
          title: 'Owner Viewed',
          actor: 'Owner',
          description: 'Hostel owner viewed the complaint details.',
          timestamp: now,
        );
        await _repository.logTimelineEvent(id, entry);
      }
    } catch (_) {
      // Silently ignore — this is a non-critical logging operation.
      // Errors here (auth transitions, permission changes) must not affect the UI.
    }
  }

  /// Admin Action: Force closes a complaint ticket.
  Future<void> forceCloseComplaint(String id, String resolutionDetails) async {
    final complaint = await _requireAdmin(id);

    final now = DateTime.now();
    final entry = TimelineEntry(
      title: 'Force Closed by Admin',
      actor: 'Admin',
      description: 'Admin force-closed this ticket: "$resolutionDetails"',
      timestamp: now,
    );

    await _repository.updateStatusAndLogTimeline(
      id,
      ComplaintStatus.closed,
      entry,
      extraFields: {'closedAt': Timestamp.fromDate(now)},
    );

    // Notify Student and Owner
    try {
      await _notificationService.sendNotification(
        title: 'Complaint Force Closed ℹ️',
        body: 'Admin force-closed "${complaint.title}": $resolutionDetails',
        userId: complaint.studentId,
        type: 'complaint_closed',
      );
      await _notificationService.sendNotification(
        title: 'Complaint Force Closed ℹ️',
        body: 'Admin force-closed "${complaint.title}": $resolutionDetails',
        userId: complaint.hostelOwnerId,
        type: 'complaint_closed',
      );
    } catch (_) {}
  }

  /// Admin Action: Reassigns a complaint to a different owner/staff.
  Future<void> reassignComplaint(String id, String newOwnerId, String newOwnerName) async {
    final complaint = await _requireAdmin(id);

    final now = DateTime.now();
    final entry = TimelineEntry(
      title: 'Reassigned by Admin',
      actor: 'Admin',
      description: 'Admin reassigned handling to owner: $newOwnerName',
      timestamp: now,
    );

    await _repository.updateStatusAndLogTimeline(
      id,
      ComplaintStatus.assigned,
      entry,
      extraFields: {
        'hostelOwnerId': newOwnerId,
      },
    );

    // Notify new Owner
    try {
      await _notificationService.sendNotification(
        title: 'Complaint Reassigned to You ⚠️',
        body: 'Admin reassigned complaint "${complaint.title}" to your property list.',
        userId: newOwnerId,
        type: 'complaint_new',
      );
    } catch (_) {}
  }

  /// Retrieves student complaints list.
  Future<List<ComplaintModel>> getStudentComplaints(String studentId) async {
    _validateAuth();
    return await _repository.getStudentComplaints(studentId);
  }

  /// Retrieves a single complaint by ID.
  Future<ComplaintModel?> getComplaint(String id) async {
    _validateAuth();
    return await _repository.getComplaint(id);
  }

  /// Streams complaints filtered by user role.
  Stream<List<ComplaintModel>> streamComplaints(String userId, String role) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }
    if (role == 'student') {
      return _repository.streamStudentComplaints(userId);
    } else if (role == 'owner') {
      return _repository.streamOwnerComplaints(userId);
    } else {
      return _repository.streamAllComplaints();
    }
  }

  /// Streams a single complaint document.
  Stream<ComplaintModel?> streamComplaint(String id) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(null);
    }
    return _repository.streamComplaint(id);
  }

  /// Admin Action: hard deletes a complaint from platform.
  Future<void> deleteComplaint(String id) async {
    await _requireAdmin(id);
    await _repository.deleteComplaint(id);
  }
}

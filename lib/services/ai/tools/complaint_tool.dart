import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../tool_interface.dart';
import '../ai_types.dart';
import '../firestore_context_service.dart';
import '../../../models/user_model.dart';

/// AI complaint tool — handles getComplaints, createComplaint, updateComplaint.
/// All status strings use camelCase enum names to match ComplaintStatus.name.
class ComplaintTool implements BaseTool {
  final FirestoreContextService _contextService = FirestoreContextService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    String userId,
    UserRole role,
  ) async {
    final startTime = DateTime.now();
    final toolName = arguments['toolName']?.toString() ?? 'getComplaints';

    try {
      // ── createComplaint ──────────────────────────────────────────
      if (toolName == 'createComplaint') {
        if (role != UserRole.student) {
          throw Exception('Only students are authorized to log complaints.');
        }

        // Validate auth
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) throw Exception('User is not authenticated.');

        // Resolve hostelOwnerId from the hostel document
        final hostelId = arguments['hostelId']?.toString() ?? '';
        String hostelOwnerId = '';
        String hostelName = arguments['hostelName']?.toString() ?? '';
        if (hostelId.isNotEmpty) {
          final hostelDoc =
              await _db.collection('hostels').doc(hostelId).get();
          if (hostelDoc.exists) {
            hostelOwnerId = hostelDoc.data()?['ownerId'] ?? '';
            if (hostelName.isEmpty) {
              hostelName = hostelDoc.data()?['name'] ?? '';
            }
          }
        }

        // Resolve student name
        String studentName = '';
        final userDoc = await _db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          studentName = userDoc.data()?['name'] ?? '';
        }

        final now = Timestamp.now();
        final initialTimeline = [
          {
            'title': 'Complaint Submitted',
            'actor': 'Student',
            'description': 'Complaint filed via AI Agent',
            'timestamp': now,
          }
        ];

        final complaintData = {
          'studentId': uid,
          'studentName': studentName,
          'hostelId': hostelId,
          'hostelName': hostelName,
          'hostelOwnerId': hostelOwnerId,
          'bookingId': arguments['bookingId'],
          'title': arguments['title'] ?? '',
          'category': arguments['category'] ?? 'Other',
          'description': arguments['description'] ?? '',
          'priority': arguments['priority'] ?? 'medium',
          'status': 'pending', // Starts as pending
          'rating': 0,
          'ownerReply': '',
          'studentResponse': '',
          'attachments': [],
          'timeline': initialTimeline,
          'createdAt': now,
          'updatedAt': now,
        };

        final ref = await _db.collection('complaints').add(complaintData);
        final elapsed = DateTime.now().difference(startTime);
        return ToolResult(
          toolName: toolName,
          success: true,
          data: {
            'complaintId': ref.id,
            'status': 'pending',
            'latestComplaintId': ref.id,
            'latestComplaintStatus': 'pending',
            'latestComplaintPriority': arguments['priority'] ?? 'medium',
          },
          executionTime: elapsed,
          metadata: {'action': 'created'},
        );
      }

      // ── updateComplaint ──────────────────────────────────────────
      if (toolName == 'updateComplaint') {
        if (role == UserRole.student) {
          throw Exception(
              'Students are not authorized to update complaint statuses.');
        }
        final complaintId = arguments['complaintId']?.toString();
        // Accept camelCase status names that match ComplaintStatus.name
        final status = arguments['status']?.toString();
        if (complaintId == null || status == null) {
          throw Exception('Missing complaintId or status parameters.');
        }
        // Normalise: accept both 'inProgress' and 'in-progress'
        final normStatus = status.replaceAll('-', '').toLowerCase() == 'inprogress'
            ? 'inProgress'
            : status;

        final doc = await _db.collection('complaints').doc(complaintId).get();
        if (!doc.exists) throw Exception('Complaint not found.');
        final priority = doc.data()?['priority'] ?? 'medium';

        final entry = {
          'title': 'Status Updated',
          'actor': role == UserRole.admin ? 'Admin' : 'Owner',
          'description': 'Complaint status changed to: $normStatus',
          'timestamp': Timestamp.now(),
        };

        await _db.collection('complaints').doc(complaintId).update({
          'status': normStatus,
          'timeline': FieldValue.arrayUnion([entry]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final elapsed = DateTime.now().difference(startTime);
        return ToolResult(
          toolName: toolName,
          success: true,
          data: {
            'complaintId': complaintId,
            'status': normStatus,
            'latestComplaintId': complaintId,
            'latestComplaintStatus': normStatus,
            'latestComplaintPriority': priority,
          },
          executionTime: elapsed,
          metadata: {'action': 'updated'},
        );
      }

      // ── getComplaints (default) ──────────────────────────────────
      final list =
          await _contextService.getComplaints(userId: userId, role: role);
      final elapsed = DateTime.now().difference(startTime);
      return ToolResult(
        toolName: toolName,
        success: true,
        data: {'complaints': list},
        executionTime: elapsed,
        metadata: {'complaintsCount': list.length},
      );
    } catch (e) {
      final elapsed = DateTime.now().difference(startTime);
      return ToolResult(
        toolName: toolName,
        success: false,
        data: {},
        error: e.toString(),
        executionTime: elapsed,
        metadata: {},
      );
    }
  }
}

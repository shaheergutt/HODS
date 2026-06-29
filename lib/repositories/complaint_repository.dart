import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';

class ComplaintRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Creates a new complaint, automatically seeding the initial "Complaint Submitted" timeline event.
  Future<String> createComplaint(ComplaintModel complaint) async {
    final docRef = _db.collection('complaints').doc();
    final now = DateTime.now();
    final initialTimeline = TimelineEntry(
      title: 'Complaint Submitted',
      actor: 'Student',
      description: 'Complaint filed by ${complaint.studentName}',
      timestamp: now,
    );
    
    final finalModel = ComplaintModel(
      id: docRef.id,
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
      status: ComplaintStatus.pending, // Always starts as Pending
      rating: complaint.rating,
      ownerReply: complaint.ownerReply,
      studentResponse: complaint.studentResponse,
      attachments: complaint.attachments,
      timeline: [initialTimeline],
      createdAt: now,
      updatedAt: now,
      resolvedAt: complaint.resolvedAt,
      closedAt: complaint.closedAt,
    );

    await docRef.set(finalModel.toMap());
    return docRef.id;
  }

  /// Appends a new timeline event to a complaint document.
  Future<void> logTimelineEvent(String id, TimelineEntry entry) async {
    await _db.collection('complaints').doc(id).update({
      'timeline': FieldValue.arrayUnion([entry.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Atomically updates a complaint's status and logs a timeline event.
  Future<void> updateStatusAndLogTimeline(
    String id,
    ComplaintStatus status,
    TimelineEntry entry, {
    Map<String, dynamic> extraFields = const {},
  }) async {
    final updateData = <String, dynamic>{
      'status': status.name,
      'timeline': FieldValue.arrayUnion([entry.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
      ...extraFields,
    };
    await _db.collection('complaints').doc(id).update(updateData);
  }

  Future<ComplaintModel?> getComplaint(String id) async {
    final doc = await _db.collection('complaints').doc(id).get();
    if (!doc.exists) return null;
    return ComplaintModel.fromMap(doc.data()!, doc.id);
  }

  Future<List<ComplaintModel>> getStudentComplaints(String studentId) async {
    final snap = await _db
        .collection('complaints')
        .where('studentId', isEqualTo: studentId)
        .get();
    final list = snap.docs
        .map((d) => ComplaintModel.fromMap(d.data(), d.id))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> updateComplaint(String id, Map<String, dynamic> data) async {
    await _db.collection('complaints').doc(id).update(data);
  }

  Future<void> deleteComplaint(String id) async {
    await _db.collection('complaints').doc(id).delete();
  }

  Stream<List<ComplaintModel>> streamStudentComplaints(String studentId) {
    return _db
        .collection('complaints')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => ComplaintModel.fromMap(d.data(), d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<ComplaintModel>> streamOwnerComplaints(String ownerId) {
    return _db
        .collection('complaints')
        .where('hostelOwnerId', isEqualTo: ownerId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => ComplaintModel.fromMap(d.data(), d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<ComplaintModel>> streamAllComplaints() {
    return _db
        .collection('complaints')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ComplaintModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<ComplaintModel?> streamComplaint(String id) {
    return _db.collection('complaints').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ComplaintModel.fromMap(doc.data()!, doc.id);
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/hostel_model.dart';
import '../models/booking_model.dart';
import '../models/complaint_model.dart';
import '../models/review_model.dart';
import '../models/room_model.dart';
import 'notification_service.dart';
import 'package:uuid/uuid.dart';
import '../core/utils/app_logger.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ════════════════════════════════════════════════════
  // AUTH / SESSION DELEGATES
  // ════════════════════════════════════════════════════

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // ════════════════════════════════════════════════════
  // USERS
  // ════════════════════════════════════════════════════

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, uid);
  }

  Stream<UserModel?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!, uid);
    });
  }

  Future<void> updateUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).update(user.toMap());
  }

  Future<void> toggleFavoriteHostel(String userId, String hostelId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;
    final map = userDoc.data()!;
    final List<String> currentFavs = List<String>.from(map['favorites'] ?? []);
    if (currentFavs.contains(hostelId)) {
      currentFavs.remove(hostelId);
    } else {
      currentFavs.add(hostelId);
    }
    await _db.collection('users').doc(userId).update({'favorites': currentFavs});
  }

  Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  // ── Admin: get owners / students ──────────────────────

  Future<List<UserModel>> getPendingOwners() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'owner')
        .get();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data(), d.id))
        .where((u) => u.approvalStatus == 'pending')
        .toList();
  }

  Future<List<UserModel>> getApprovedOwners() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'owner')
        .get();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data(), d.id))
        .where((u) => u.approvalStatus == 'approved')
        .toList();
  }

  Future<List<UserModel>> getAllOwners() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'owner')
        .get();
    return snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
  }

  Future<List<UserModel>> getAllStudents() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'student')
        .get();
    return snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
  }

  Future<void> approveOwner(String uid, String licenseNumber) async {
    await _db.collection('users').doc(uid).update({
      'isApproved': true,
      'licenseNumber': licenseNumber,
      'approvalStatus': 'approved',
    });
  }

  Future<void> rejectOwner(String uid) async {
    await _db.collection('users').doc(uid).update({
      'isApproved': false,
      'approvalStatus': 'rejected',
    });
  }

  // ════════════════════════════════════════════════════
  // HOSTELS
  // ════════════════════════════════════════════════════

  Future<String> createHostel(HostelModel hostel) async {
    final id = hostel.id.isNotEmpty ? hostel.id : _uuid.v4();
    await _db.collection('hostels').doc(id).set(hostel.copyWith(id: id).toMap());
    return id;
  }

  Future<void> updateHostel(HostelModel hostel) async {
    await _db.collection('hostels').doc(hostel.id).update(hostel.toMap());
  }

  Future<void> deleteHostel(String id) async {
    // Soft delete
    await _db.collection('hostels').doc(id).update({'isActive': false});
  }

  Stream<List<HostelModel>> getAllHostels() {
    return _db
        .collection('hostels')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => HostelModel.fromMap(d.data(), d.id))
              .where((h) => h.isActive)
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<HostelModel>> getOwnerHostels(String ownerId) {
    return _db
        .collection('hostels')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => HostelModel.fromMap(d.data(), d.id))
            .where((h) => h.isActive)
            .toList());
  }

  Future<HostelModel?> getHostel(String id) async {
    final doc = await _db.collection('hostels').doc(id).get();
    if (!doc.exists) return null;
    return HostelModel.fromMap(doc.data()!, id);
  }

  Future<List<HostelModel>> getPendingHostels() async {
    final snap = await _db.collection('hostels').get();
    return snap.docs
        .map((d) => HostelModel.fromMap(d.data(), d.id))
        .where((h) => h.isActive && !h.isApproved)
        .toList();
  }

  Future<List<HostelModel>> getApprovedHostels() async {
    final snap = await _db.collection('hostels').get();
    return snap.docs
        .map((d) => HostelModel.fromMap(d.data(), d.id))
        .where((h) => h.isActive && h.isApproved)
        .toList();
  }

  Future<void> approveHostel(String hostelId) async {
    await _db.collection('hostels').doc(hostelId).update({'isApproved': true});
  }

  Future<void> rejectHostel(String hostelId) async {
    await _db.collection('hostels').doc(hostelId).update({
      'isApproved': false,
      'isActive': false,
    });
  }

  // ════════════════════════════════════════════════════
  // ROOMS
  // ════════════════════════════════════════════════════

  Future<String> createRoom(RoomModel room) async {
    final id = room.roomId.isNotEmpty ? room.roomId : _uuid.v4();
    await _db.collection('rooms').doc(id).set(room.copyWith(roomId: id).toMap());
    return id;
  }

  Future<void> updateRoom(RoomModel room) async {
    await _db.collection('rooms').doc(room.roomId).update(room.toMap());
  }

  Future<void> deleteRoom(String id) async {
    await _db.collection('rooms').doc(id).update({'isActive': false});
  }

  Stream<List<RoomModel>> getHostelRooms(String hostelId) {
    return _db
        .collection('rooms')
        .where('hostelId', isEqualTo: hostelId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RoomModel.fromMap(d.data(), d.id))
            .where((r) => r.isActive)
            .toList());
  }

  Future<RoomModel?> getRoom(String id) async {
    final doc = await _db.collection('rooms').doc(id).get();
    if (!doc.exists) return null;
    return RoomModel.fromMap(doc.data()!, id);
  }

  Stream<List<RoomModel>> getOwnerRooms(List<String> hostelIds) {
    return _db
        .collection('rooms')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RoomModel.fromMap(d.data(), d.id))
            .where((r) => r.isActive && hostelIds.contains(r.hostelId))
            .toList());
  }

  // ════════════════════════════════════════════════════
  // BOOKINGS
  // ════════════════════════════════════════════════════

  Future<String> createBooking(BookingModel booking) async {
    final id = _uuid.v4();
    await _db.collection('bookings').doc(id).set(booking.toMap());
    // Update the ID inside the document as well
    await _db.collection('bookings').doc(id).update({'id': id});
    return id;
  }

  Stream<List<BookingModel>> getStudentBookings(String studentId) {
    return _db
        .collection('bookings')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => BookingModel.fromMap(d.data(), d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<BookingModel>> getOwnerBookings(String ownerId) {
    return _db
        .collection('bookings')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => BookingModel.fromMap(d.data(), d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<BookingModel>> getAllBookings() {
    return _db
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> updateBookingStatus(String id, BookingStatus status) async {
    // 1. Get current booking info
    final bookingDoc = await _db.collection('bookings').doc(id).get();
    if (!bookingDoc.exists) return;
    final booking = BookingModel.fromMap(bookingDoc.data()!, id);

    // If booking is being confirmed, ensure QR token exists
    if (status == BookingStatus.confirmed && booking.qrToken == null) {
      final newQrToken = _uuid.v4();
      final now = DateTime.now();
      await _db.collection('bookings').doc(id).update({
        'qrToken': newQrToken,
        'qrGeneratedAt': Timestamp.fromDate(now),
        'checkedIn': false,
        'checkedOut': false,
      });
      AppLogger.i('QR generated for booking $id');
    }

    // 2. Perform actions if status changed to confirmed
    if (status == BookingStatus.confirmed && booking.status != BookingStatus.confirmed) {
      if (booking.roomId.isNotEmpty) {
        final roomDoc = await _db.collection('rooms').doc(booking.roomId).get();
        if (roomDoc.exists) {
          final room = RoomModel.fromMap(roomDoc.data()!, booking.roomId);
          final newAvailable = (room.availableBeds - booking.bedsBooked).clamp(0, room.capacity);
          final newOccupied = (room.occupiedBeds + booking.bedsBooked).clamp(0, room.capacity);

          await _db.collection('rooms').doc(booking.roomId).update({
            'availableBeds': newAvailable,
            'occupiedBeds': newOccupied,
          });

          // Recalculate hostel availability
          await recalculateHostelAvailability(booking.hostelId);
        }
      }

      // Create notification
      try {
        final notifService = NotificationService();
        await notifService.sendNotification(
          title: 'Booking Confirmed 🎉',
          body: 'Your booking for ${booking.bedsBooked} bed(s) in Room ${booking.roomNumber} at ${booking.hostelName} is confirmed!',
          userId: booking.studentId,
          type: 'booking_confirmed',
        );
      } catch (e) {
        AppLogger.e('FCM notification simulation logging error', e);
      }
    }

    // Perform actions if status changed to cancelled from confirmed
    if (status == BookingStatus.cancelled && booking.status == BookingStatus.confirmed) {
      if (booking.roomId.isNotEmpty) {
        final roomDoc = await _db.collection('rooms').doc(booking.roomId).get();
        if (roomDoc.exists) {
          final room = RoomModel.fromMap(roomDoc.data()!, booking.roomId);
          final newAvailable = (room.availableBeds + booking.bedsBooked).clamp(0, room.capacity);
          final newOccupied = (room.occupiedBeds - booking.bedsBooked).clamp(0, room.capacity);

          await _db.collection('rooms').doc(booking.roomId).update({
            'availableBeds': newAvailable,
            'occupiedBeds': newOccupied,
          });

          // Recalculate hostel availability
          await recalculateHostelAvailability(booking.hostelId);
        }
      }

      // Create notification
      try {
        final notifService = NotificationService();
        await notifService.sendNotification(
          title: 'Booking Cancelled ℹ️',
          body: 'Your booking at ${booking.hostelName} has been cancelled.',
          userId: booking.studentId,
          type: 'booking_cancelled',
        );
      } catch (e) {
        AppLogger.e('FCM notification simulation logging error', e);
      }
    } else if (status == BookingStatus.cancelled && booking.status == BookingStatus.pending) {
      // Create notification
      try {
        final notifService = NotificationService();
        await notifService.sendNotification(
          title: 'Booking Request Cancelled ℹ️',
          body: 'Your booking request at ${booking.hostelName} has been cancelled.',
          userId: booking.studentId,
          type: 'booking_cancelled',
        );
      } catch (e) {
        AppLogger.e('FCM notification simulation logging error', e);
      }
    }

    // 3. Update status
    await _db.collection('bookings').doc(id).update({'status': status.name});
  }

  Future<void> recalculateHostelAvailability(String hostelId) async {
    final roomsSnap = await _db.collection('rooms').where('hostelId', isEqualTo: hostelId).get();
    int availableRoomsCount = 0;
    for (final doc in roomsSnap.docs) {
      if (doc.data()['isActive'] != false) {
        final availableBeds = doc.data()['availableBeds'] ?? 0;
        if (availableBeds > 0) {
          availableRoomsCount++;
        }
      }
    }
    await _db.collection('hostels').doc(hostelId).update({
      'availableRooms': availableRoomsCount,
    });
  }

  // ════════════════════════════════════════════════════
  // REVIEWS
  // ════════════════════════════════════════════════════

  Future<void> addReview(ReviewModel review) async {
    final id = _uuid.v4();
    await _db.collection('reviews').doc(id).set(review.toMap());
    // Update the ID inside the document as well
    await _db.collection('reviews').doc(id).update({'id': id});

    // Update hostel average rating and review count
    final reviews = await _db
        .collection('reviews')
        .where('hostelId', isEqualTo: review.hostelId)
        .get();
    final totalRating =
        reviews.docs.fold(0.0, (acc, d) => acc + (d.data()['rating'] ?? 0.0));
    final avgRating = reviews.docs.isEmpty ? 0.0 : totalRating / reviews.docs.length;
    await _db.collection('hostels').doc(review.hostelId).update({
      'rating': avgRating,
      'reviewCount': reviews.docs.length,
    });
  }

  Future<List<ReviewModel>> getHostelReviews(String hostelId) async {
    try {
      final snap = await _db
          .collection('reviews')
          .where('hostelId', isEqualTo: hostelId)
          .get();
      final list = snap.docs.map((d) => ReviewModel.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      AppLogger.e('Error getting reviews', e);
      return [];
    }
  }

  // ════════════════════════════════════════════════════
  // COMPLAINTS
  // ════════════════════════════════════════════════════

  /// Creates a new complaint. Validates auth before writing.
  Future<String> createComplaint(ComplaintModel complaint) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('You must be logged in to file a complaint.');
    if (currentUser.uid != complaint.studentId) {
      throw Exception('You are not authorized to file this complaint.');
    }
    final id = _uuid.v4();
    final now = DateTime.now();
    final data = complaint.toMap();
    data['createdAt'] = Timestamp.fromDate(now);
    data['updatedAt'] = Timestamp.fromDate(now);
    await _db.collection('complaints').doc(id).set(data);
    return id;
  }

  /// Updates specific fields on a complaint document.
  Future<void> updateComplaint(String id, Map<String, dynamic> fields) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('You must be logged in.');
    final update = Map<String, dynamic>.from(fields);
    update['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('complaints').doc(id).update(update);
  }

  /// Owner: sets status + writes reply message.
  Future<void> replyToComplaint({
    required String complaintId,
    required String reply,
    required ComplaintStatus newStatus,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('You must be logged in.');
    final update = <String, dynamic>{
      'ownerReply': reply,
      'status': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (newStatus == ComplaintStatus.resolved) {
      update['resolvedAt'] = FieldValue.serverTimestamp();
    }
    await _db.collection('complaints').doc(complaintId).update(update);
  }

  /// Student: closes the complaint and saves satisfaction rating.
  Future<void> closeComplaint(String complaintId, int rating) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('You must be logged in.');
    await _db.collection('complaints').doc(complaintId).update({
      'status': ComplaintStatus.closed.name,
      'rating': rating,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin only — hard-deletes a complaint.
  Future<void> deleteComplaint(String id) async {
    await _db.collection('complaints').doc(id).delete();
  }

  /// Fetches a single complaint by ID.
  Future<ComplaintModel?> getComplaint(String id) async {
    final doc = await _db.collection('complaints').doc(id).get();
    if (!doc.exists) return null;
    return ComplaintModel.fromMap(doc.data()!, doc.id);
  }

  /// Real-time stream of a student's complaints, newest first.
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

  /// Real-time stream of complaints for a hostel owner's properties.
  /// Uses the denormalized `hostelOwnerId` field for an efficient server-side query.
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

  /// Real-time stream of all complaints — admin use only.
  Stream<List<ComplaintModel>> streamAllComplaints() {
    return _db
        .collection('complaints')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ComplaintModel.fromMap(d.data(), d.id)).toList());
  }

  /// Real-time stream of a single complaint document.
  Stream<ComplaintModel?> streamComplaint(String id) {
    return _db.collection('complaints').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ComplaintModel.fromMap(doc.data()!, doc.id);
    });
  }


  // ════════════════════════════════════════════════════
  // ADMIN STATS
  // ════════════════════════════════════════════════════

  Future<Map<String, int>> getAdminStats() async {
    final users = await _db.collection('users').get();
    final hostels = await _db.collection('hostels').get();
    final bookings = await _db.collection('bookings').get();

    int students = 0;
    int owners = 0;
    int pendingOwners = 0;
    for (final doc in users.docs) {
      final role = doc.data()['role'];
      if (role == 'student') {
        students++;
      } else if (role == 'owner') {
        owners++;
        if (doc.data()['isApproved'] != true) {
          pendingOwners++;
        }
      }
    }

    int pendingHostels = 0;
    for (final doc in hostels.docs) {
      final data = doc.data();
      if (data['isActive'] == true && data['isApproved'] != true) {
        pendingHostels++;
      }
    }

    return {
      'totalUsers': users.docs.length,
      'totalStudents': students,
      'totalOwners': owners,
      'pendingOwners': pendingOwners,
      'totalHostels': hostels.docs.length,
      'pendingHostels': pendingHostels,
      'totalBookings': bookings.docs.length,
    };
  }
}

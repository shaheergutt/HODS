import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/hostel_model.dart';
import '../../models/room_model.dart';

class FirestoreContextService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Retrieves user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (_) {}
    return null;
  }

  /// Retrieves bookings securely based on role
  Future<List<Map<String, dynamic>>> getBookings({
    required String userId,
    required UserRole role,
  }) async {
    final list = <Map<String, dynamic>>[];
    try {
      Query query = _db.collection('bookings');
      if (role == UserRole.student) {
        query = query.where('studentId', isEqualTo: userId);
      } else if (role == UserRole.owner) {
        query = query.where('ownerId', isEqualTo: userId);
      } else if (role != UserRole.admin) {
        return []; // Security check
      }

      final snap = await query.get();
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        list.add({
          'id': doc.id,
          'hostelName': data['hostelName'] ?? '',
          'roomNumber': data['roomNumber'] ?? '',
          'bedsBooked': data['bedsBooked'] ?? 1,
          'totalAmount': data['totalAmount'] ?? 0,
          'status': data['status'] ?? 'pending',
          'checkInDate': data['checkInDate']?.toString() ?? '',
          'checkOutDate': data['checkOutDate']?.toString() ?? '',
        });
      }
    } catch (_) {}
    return list;
  }

  /// Retrieves complaints securely based on role
  Future<List<Map<String, dynamic>>> getComplaints({
    required String userId,
    required UserRole role,
  }) async {
    final list = <Map<String, dynamic>>[];
    try {
      Query query = _db.collection('complaints');
      if (role == UserRole.student) {
        query = query.where('studentId', isEqualTo: userId);
      } else if (role == UserRole.owner) {
        query = query.where('hostelOwnerId', isEqualTo: userId);
      } else if (role != UserRole.admin) {
        return []; // Security check
      }

      final snap = await query.get();
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        list.add({
          'id': doc.id,
          'title': data['title'] ?? '',
          'category': data['category'] ?? '',
          'description': data['description'] ?? '',
          'status': data['status'] ?? 'open',
          'hostelName': data['hostelName'] ?? '',
        });
      }
    } catch (_) {}
    return list;
  }

  /// Retrieves hostels matching city filter or university
  Future<List<HostelModel>> getApprovedHostels() async {
    try {
      final snap = await _db.collection('hostels').where('isApproved', isEqualTo: true).get();
      return snap.docs.map((d) => HostelModel.fromMap(d.data(), d.id)).toList();
    } catch (_) {}
    return [];
  }

  /// Retrieves active rooms
  Future<List<RoomModel>> getActiveRooms() async {
    try {
      final snap = await _db.collection('rooms').where('isActive', isEqualTo: true).get();
      return snap.docs.map((d) => RoomModel.fromMap(d.data(), d.id)).toList();
    } catch (_) {}
    return [];
  }

  /// Retrieves platform statistics for admins securely
  Future<Map<String, dynamic>?> getPlatformStats(UserRole role) async {
    if (role != UserRole.admin) return null; // Security check
    try {
      final usersSnap = await _db.collection('users').get();
      final hostelsSnap = await _db.collection('hostels').get();
      final bookingsSnap = await _db.collection('bookings').get();

      return {
        'totalUsers': usersSnap.docs.length,
        'totalHostels': hostelsSnap.docs.length,
        'totalBookings': bookingsSnap.docs.length,
      };
    } catch (_) {}
    return null;
  }

  /// Retrieves business analytics for owners securely
  Future<Map<String, dynamic>?> getOwnerBusinessStats(String userId, UserRole role) async {
    if (role != UserRole.owner && role != UserRole.admin) return null; // Security check
    try {
      final hostelsSnap = await _db.collection('hostels').where('ownerId', isEqualTo: userId).get();
      final hostels = hostelsSnap.docs.map((d) => HostelModel.fromMap(d.data(), d.id)).toList();

      final bookingsSnap = await _db.collection('bookings').where('ownerId', isEqualTo: userId).get();
      final bookings = bookingsSnap.docs.map((d) => d.data()).toList();

      final complaintsSnap = await _db.collection('complaints').where('hostelOwnerId', isEqualTo: userId).get();
      final complaints = complaintsSnap.docs.map((d) => d.data()).toList();

      double totalRevenue = 0.0;
      int activeBookings = 0;
      int pendingBookings = 0;
      int totalBedsBooked = 0;

      for (final b in bookings) {
        final status = b['status'] ?? 'pending';
        final amount = (b['totalAmount'] ?? 0.0) as num;
        if (status == 'approved' || status == 'confirmed') {
          totalRevenue += amount.toDouble();
          activeBookings++;
          totalBedsBooked += (b['bedsBooked'] ?? 1) as int;
        } else if (status == 'pending') {
          pendingBookings++;
        }
      }

      return {
        'hostelsOwned': hostels.length,
        'totalRevenue': totalRevenue,
        'activeBookings': activeBookings,
        'pendingBookings': pendingBookings,
        'totalBedsBooked': totalBedsBooked,
        'totalComplaints': complaints.length,
        'pendingComplaints': complaints.where((c) => c['status'] != 'resolved' && c['status'] != 'closed').length,
      };
    } catch (_) {}
    return null;
  }

  Future<Map<String, double>?> getUniversityCoordinates(String name) async {
    try {
      final snap = await _db.collection('universities').get();
      final queryStr = name.toLowerCase().trim();
      for (final doc in snap.docs) {
        final data = doc.data();
        final nameVal = (data['name'] ?? '').toString().toLowerCase();
        final aliases = List<String>.from(data['aliases'] ?? []);
        if (nameVal.contains(queryStr) || queryStr.contains(nameVal)) {
          return {
            'lat': (data['latitude'] as num).toDouble(),
            'lng': (data['longitude'] as num).toDouble(),
          };
        }
        for (final alias in aliases) {
          if (queryStr.contains(alias.toLowerCase()) || alias.toLowerCase().contains(queryStr)) {
            return {
              'lat': (data['latitude'] as num).toDouble(),
              'lng': (data['longitude'] as num).toDouble(),
            };
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, double>?> getCityCoordinates(String name) async {
    try {
      final snap = await _db.collection('cities').get();
      final queryStr = name.toLowerCase().trim();
      for (final doc in snap.docs) {
        final data = doc.data();
        final nameVal = (data['name'] ?? '').toString().toLowerCase();
        final aliases = List<String>.from(data['aliases'] ?? []);
        if (nameVal.contains(queryStr) || queryStr.contains(nameVal)) {
          return {
            'lat': (data['latitude'] as num).toDouble(),
            'lng': (data['longitude'] as num).toDouble(),
          };
        }
        for (final alias in aliases) {
          if (queryStr.contains(alias.toLowerCase()) || alias.toLowerCase().contains(queryStr)) {
            return {
              'lat': (data['latitude'] as num).toDouble(),
              'lng': (data['longitude'] as num).toDouble(),
            };
          }
        }
      }
    } catch (_) {}
    return null;
  }
}

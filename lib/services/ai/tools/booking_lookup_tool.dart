import 'package:cloud_firestore/cloud_firestore.dart';
import '../tool_interface.dart';
import '../ai_types.dart';
import '../firestore_context_service.dart';
import '../../../models/user_model.dart';

class BookingLookupTool implements BaseTool {
  final FirestoreContextService _contextService = FirestoreContextService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    String userId,
    UserRole role,
  ) async {
    final startTime = DateTime.now();
    final toolName = arguments['toolName']?.toString() ?? 'getBookings';
    try {
      if (toolName == 'createBooking') {
        if (role != UserRole.student) {
          throw Exception('Only students are authorized to create bookings.');
        }
        final bookingData = {
          'studentId': userId,
          'hostelId': arguments['hostelId'],
          'hostelName': arguments['hostelName'] ?? '',
          'roomNumber': arguments['roomNumber'] ?? '',
          'bedsBooked': arguments['bedsBooked'] ?? 1,
          'totalAmount': arguments['totalAmount'] ?? 0,
          'status': 'pending',
          'checkInDate': arguments['checkInDate'],
          'checkOutDate': arguments['checkOutDate'],
          'createdAt': FieldValue.serverTimestamp(),
        };
        final ref = await _db.collection('bookings').add(bookingData);
        final elapsed = DateTime.now().difference(startTime);
        return ToolResult(
          toolName: toolName,
          success: true,
          data: {'bookingId': ref.id, 'details': bookingData},
          executionTime: elapsed,
          metadata: {'action': 'created'},
        );
      }

      if (toolName == 'cancelBooking') {
        final bookingId = arguments['bookingId']?.toString();
        if (bookingId == null) {
          throw Exception('Missing bookingId parameter.');
        }

        final doc = await _db.collection('bookings').doc(bookingId).get();
        if (!doc.exists) {
          throw Exception('Booking not found.');
        }

        final data = doc.data()!;
        if (role == UserRole.student && data['studentId'] != userId) {
          throw Exception('Unauthorized to cancel this booking.');
        }

        await _db.collection('bookings').doc(bookingId).update({'status': 'cancelled'});
        final elapsed = DateTime.now().difference(startTime);
        return ToolResult(
          toolName: toolName,
          success: true,
          data: {'bookingId': bookingId, 'message': 'Cancelled successfully'},
          executionTime: elapsed,
          metadata: {'action': 'cancelled'},
        );
      }

      if (toolName == 'trackBooking') {
        final bookingId = arguments['bookingId']?.toString();
        if (bookingId == null) {
          throw Exception('Missing bookingId parameter.');
        }
        final doc = await _db.collection('bookings').doc(bookingId).get();
        if (!doc.exists) {
          throw Exception('Booking not found.');
        }
        final elapsed = DateTime.now().difference(startTime);
        return ToolResult(
          toolName: toolName,
          success: true,
          data: doc.data() ?? {},
          executionTime: elapsed,
          metadata: {'bookingId': bookingId},
        );
      }

      // Default getBookings
      final list = await _contextService.getBookings(userId: userId, role: role);
      final elapsed = DateTime.now().difference(startTime);
      return ToolResult(
        toolName: toolName,
        success: true,
        data: {'bookings': list},
        executionTime: elapsed,
        metadata: {'bookingsCount': list.length},
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

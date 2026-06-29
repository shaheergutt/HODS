import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking_model.dart';
import 'hostel_provider.dart';

final studentBookingsProvider =
    StreamProvider.family<List<BookingModel>, String>((ref, studentId) {
  return ref.watch(firestoreServiceProvider).getStudentBookings(studentId);
});

final ownerBookingsProvider =
    StreamProvider.family<List<BookingModel>, String>((ref, ownerId) {
  return ref.watch(firestoreServiceProvider).getOwnerBookings(ownerId);
});

final allBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getAllBookings();
});

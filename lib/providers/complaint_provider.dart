import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/complaint_model.dart';
import '../repositories/complaint_repository.dart';
import '../services/complaints/complaint_service.dart';
import 'auth_provider.dart';

final complaintRepositoryProvider = Provider<ComplaintRepository>((ref) {
  return ComplaintRepository();
});

final complaintServiceProvider = Provider<ComplaintService>((ref) {
  final repository = ref.watch(complaintRepositoryProvider);
  // Watch auth state so this provider re-creates when user logs in/out.
  ref.watch(authStateProvider);
  return ComplaintService(repository);
});

// ── Student stream — real-time list of own complaints ──────────────
// Watches authStateProvider so stream cancels on logout and restarts on login.
final studentComplaintsProvider =
    StreamProvider.family<List<ComplaintModel>, String>((ref, studentId) {
  final authState = ref.watch(authStateProvider);
  // If not authenticated, return an empty stream immediately.
  if (authState.value == null) return Stream.value([]);
  return ref.watch(complaintServiceProvider).streamComplaints(studentId, 'student');
});

// ── Owner stream — scoped to hostelOwnerId, server-side filtered ───
// Watches authStateProvider so stream cancels on logout and restarts on login.
final ownerComplaintsProvider =
    StreamProvider.family<List<ComplaintModel>, String>((ref, ownerId) {
  final authState = ref.watch(authStateProvider);
  // If not authenticated, return an empty stream immediately.
  if (authState.value == null) return Stream.value([]);
  return ref.watch(complaintServiceProvider).streamComplaints(ownerId, 'owner');
});

// ── Admin stream — all complaints ──────────────────────────────────
// Watches authStateProvider so stream cancels on logout and restarts on login.
final allComplaintsProvider = StreamProvider<List<ComplaintModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  // If not authenticated, return an empty stream immediately.
  if (authState.value == null) return Stream.value([]);
  return ref.watch(complaintServiceProvider).streamComplaints('', 'admin');
});

// ── Single complaint stream provider ───────────────────────────────
// Watches authStateProvider so stream cancels on logout and restarts on login.
final complaintStreamProvider =
    StreamProvider.family<ComplaintModel?, String>((ref, complaintId) {
  final authState = ref.watch(authStateProvider);
  // If not authenticated, return null stream immediately.
  if (authState.value == null) return Stream.value(null);
  return ref.watch(complaintServiceProvider).streamComplaint(complaintId);
});

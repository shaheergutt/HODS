import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final firestoreServiceProvider = Provider((ref) => FirestoreService());

/// AsyncValue<UserModel?> — use .when() on this in UI widgets
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).userStream(user.uid);
});

/// Convenience synchronous access — may be null while loading
final currentUserValueProvider = Provider<UserModel?>((ref) {
  return ref.watch(currentUserProvider).value;
});

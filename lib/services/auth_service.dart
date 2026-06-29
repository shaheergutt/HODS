import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Auth State Changes ────────────────────────────────────────
  // Emits the current user on subscribe, then updates on login/logout
  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return await getCurrentUserModel();
    });
  }

  // ── Register Student ─────────────────────────────────────────
  Future<UserModel> registerStudent({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String? university,
    required String? preferredCity,
    required List<String> preferredFacilities,
    required String preferredGender,
    required int budgetMin,
    required int budgetMax,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final user = UserModel(
      uid: cred.user!.uid,
      name: name,
      email: email,
      role: UserRole.student,
      phone: phone,
      university: university,
      preferredCity: preferredCity,
      preferredFacilities: preferredFacilities,
      preferredGender: preferredGender,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(cred.user!.uid).set(user.toMap());
    return user;
  }

  // ── Register Owner ────────────────────────────────────────────
  Future<UserModel> registerOwner({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String? businessName,
    required String? cnic,
    String hostelAddress = '',
    String licenseNumber = '',
    String? documentUrl,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final user = UserModel(
      uid: cred.user!.uid,
      name: name,
      email: email,
      role: UserRole.owner,
      phone: phone,
      businessName: businessName,
      cnic: cnic,
      hostelAddress: hostelAddress,
      licenseNumber: licenseNumber,
      isApproved: false,
      approvalStatus: 'pending',
      documentUrl: documentUrl,
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(cred.user!.uid).set(user.toMap());
    return user;
  }

  // ── Login ─────────────────────────────────────────────────────
  Future<UserModel?> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return await getCurrentUserModel();
  }

  // ── Sign Out ──────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // keep backward compat alias
  Future<void> logout() async => signOut();

  // ── Get Current User Model ────────────────────────────────────
  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _fetchUser(user.uid);
  }

  // ── Fetch User ────────────────────────────────────────────────
  Future<UserModel?> _fetchUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, uid);
  }

  // ── Password Reset ────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, owner, admin }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String phone;
  final String profileImageUrl;
  final List<String> favorites;

  // Student-specific
  final String? preferredCity;
  final List<String> preferredFacilities;
  final String preferredGender;
  final int budgetMin;
  final int budgetMax;
  final String? university;
  final String cleanlinessPref;
  final String noisePref;
  final String sharingPref;
  final String dietPref;
  final String transportPref;

  // Owner-specific
  final String licenseNumber;
  final bool isApproved;
  final String approvalStatus; // 'pending', 'approved', 'rejected'
  final String? businessName;
  final String? cnic;
  final String? hostelAddress;
  final String? documentUrl;

  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.profileImageUrl = '',
    this.favorites = const [],
    this.preferredCity,
    this.preferredFacilities = const [],
    this.preferredGender = 'mixed',
    this.budgetMin = 0,
    this.budgetMax = 50000,
    this.university,
    this.cleanlinessPref = 'any',
    this.noisePref = 'any',
    this.sharingPref = 'any',
    this.dietPref = 'any',
    this.transportPref = 'any',
    this.licenseNumber = '',
    this.isApproved = false,
    this.approvalStatus = 'approved',
    this.businessName,
    this.cnic,
    this.hostelAddress,
    this.documentUrl,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }
    final role = _roleFromString(map['role'] ?? 'student');
    final isApprovedVal = map['isApproved'] ?? false;
    final approvalStatusVal = map['approvalStatus'] ?? (role == UserRole.owner ? (isApprovedVal ? 'approved' : 'pending') : 'approved');

    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: role,
      phone: map['phone'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
      favorites: List<String>.from(map['favorites'] ?? []),
      preferredCity: map['preferredCity'],
      preferredFacilities: List<String>.from(map['preferredFacilities'] ?? []),
      preferredGender: map['preferredGender'] ?? 'mixed',
      budgetMin: map['budgetMin'] ?? 0,
      budgetMax: map['budgetMax'] ?? 50000,
      university: map['university'],
      cleanlinessPref: map['cleanlinessPref'] ?? 'any',
      noisePref: map['noisePref'] ?? 'any',
      sharingPref: map['sharingPref'] ?? 'any',
      dietPref: map['dietPref'] ?? 'any',
      transportPref: map['transportPref'] ?? 'any',
      licenseNumber: map['licenseNumber'] ?? '',
      isApproved: isApprovedVal,
      approvalStatus: approvalStatusVal,
      businessName: map['businessName'],
      cnic: map['cnic'],
      hostelAddress: map['hostelAddress'],
      documentUrl: map['documentUrl'],
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
      'phone': phone,
      'profileImageUrl': profileImageUrl,
      'favorites': favorites,
      'preferredCity': preferredCity,
      'preferredFacilities': preferredFacilities,
      'preferredGender': preferredGender,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'university': university,
      'cleanlinessPref': cleanlinessPref,
      'noisePref': noisePref,
      'sharingPref': sharingPref,
      'dietPref': dietPref,
      'transportPref': transportPref,
      'licenseNumber': licenseNumber,
      'isApproved': isApproved,
      'approvalStatus': approvalStatus,
      'businessName': businessName,
      'cnic': cnic,
      'hostelAddress': hostelAddress,
      'documentUrl': documentUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? profileImageUrl,
    List<String>? favorites,
    String? preferredCity,
    List<String>? preferredFacilities,
    String? preferredGender,
    int? budgetMin,
    int? budgetMax,
    String? university,
    String? cleanlinessPref,
    String? noisePref,
    String? sharingPref,
    String? dietPref,
    String? transportPref,
    String? licenseNumber,
    bool? isApproved,
    String? approvalStatus,
    String? businessName,
    String? cnic,
    String? hostelAddress,
    String? documentUrl,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      role: role,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      favorites: favorites ?? this.favorites,
      preferredCity: preferredCity ?? this.preferredCity,
      preferredFacilities: preferredFacilities ?? this.preferredFacilities,
      preferredGender: preferredGender ?? this.preferredGender,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      university: university ?? this.university,
      cleanlinessPref: cleanlinessPref ?? this.cleanlinessPref,
      noisePref: noisePref ?? this.noisePref,
      sharingPref: sharingPref ?? this.sharingPref,
      dietPref: dietPref ?? this.dietPref,
      transportPref: transportPref ?? this.transportPref,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      isApproved: isApproved ?? this.isApproved,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      businessName: businessName ?? this.businessName,
      cnic: cnic ?? this.cnic,
      hostelAddress: hostelAddress ?? this.hostelAddress,
      documentUrl: documentUrl ?? this.documentUrl,
      createdAt: createdAt,
    );
  }

  static UserRole _roleFromString(String role) {
    switch (role) {
      case 'owner': return UserRole.owner;
      case 'admin': return UserRole.admin;
      default: return UserRole.student;
    }
  }
}

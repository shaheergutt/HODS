import 'package:cloud_firestore/cloud_firestore.dart';

class HostelModel {
  final String id;
  final String ownerId;
  final String ownerName;
  final String name;
  final String description;
  final String location;
  final String city;
  final double pricePerMonth;
  final int totalRooms;
  final int availableRooms;
  final List<String> facilities;
  final List<String> imageUrls;
  final double rating;
  final int reviewCount;
  final String genderPolicy; // 'Male', 'Female', 'Both'
  final String licenseNumber;
  final bool isApproved;
  final double pricePerDay;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  // New fields for pricing & soft-delete
  final double? dailyRate;
  final double? weeklyRate;
  final double? monthlyRate;
  final bool isActive;

  const HostelModel({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.name,
    required this.description,
    required this.location,
    required this.city,
    required this.pricePerMonth,
    required this.totalRooms,
    required this.availableRooms,
    required this.facilities,
    this.imageUrls = const [],
    this.rating = 0.0,
    this.reviewCount = 0,
    this.genderPolicy = 'Both',
    this.licenseNumber = '',
    this.isApproved = false,
    this.pricePerDay = 1200.0,
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.createdAt,
    this.dailyRate,
    this.weeklyRate,
    this.monthlyRate,
    this.isActive = true,
  });

  factory HostelModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }
    return HostelModel(
      id: id,
      ownerId: map['ownerId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      city: map['city'] ?? '',
      pricePerMonth: (map['pricePerMonth'] ?? map['monthlyRate'] ?? 0).toDouble(),
      totalRooms: map['totalRooms'] ?? 0,
      availableRooms: map['availableRooms'] ?? 0,
      facilities: List<String>.from(map['facilities'] ?? []),
      imageUrls: List<String>.from(map['imageUrls'] ?? map['images'] ?? []),
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      genderPolicy: map['genderPolicy'] ?? map['targetGender'] ?? 'Both',
      licenseNumber: map['licenseNumber'] ?? '',
      isApproved: map['isApproved'] ?? map['isActive'] ?? false,
      pricePerDay: (map['pricePerDay'] ?? map['dailyRate'] ?? 1200.0).toDouble(),
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      createdAt: parseDate(map['createdAt']),
      dailyRate: map['dailyRate'] != null ? (map['dailyRate'] as num).toDouble() : null,
      weeklyRate: map['weeklyRate'] != null ? (map['weeklyRate'] as num).toDouble() : null,
      monthlyRate: map['monthlyRate'] != null ? (map['monthlyRate'] as num).toDouble() : null,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'name': name,
      'description': description,
      'location': location,
      'city': city,
      'pricePerMonth': pricePerMonth,
      'totalRooms': totalRooms,
      'availableRooms': availableRooms,
      'facilities': facilities,
      'imageUrls': imageUrls,
      'rating': rating,
      'reviewCount': reviewCount,
      'genderPolicy': genderPolicy,
      'licenseNumber': licenseNumber,
      'isApproved': isApproved,
      'pricePerDay': pricePerDay,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'dailyRate': dailyRate,
      'weeklyRate': weeklyRate,
      'monthlyRate': monthlyRate,
      'isActive': isActive,
    };
  }

  HostelModel copyWith({
    String? id,
    String? name,
    String? description,
    String? location,
    String? city,
    double? pricePerMonth,
    int? totalRooms,
    int? availableRooms,
    List<String>? facilities,
    List<String>? imageUrls,
    double? rating,
    int? reviewCount,
    String? genderPolicy,
    String? licenseNumber,
    bool? isApproved,
    double? pricePerDay,
    double? latitude,
    double? longitude,
    double? dailyRate,
    double? weeklyRate,
    double? monthlyRate,
    bool? isActive,
  }) {
    return HostelModel(
      id: id ?? this.id,
      ownerId: ownerId,
      ownerName: ownerName,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      city: city ?? this.city,
      pricePerMonth: pricePerMonth ?? this.pricePerMonth,
      totalRooms: totalRooms ?? this.totalRooms,
      availableRooms: availableRooms ?? this.availableRooms,
      facilities: facilities ?? this.facilities,
      imageUrls: imageUrls ?? this.imageUrls,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      genderPolicy: genderPolicy ?? this.genderPolicy,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      isApproved: isApproved ?? this.isApproved,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt,
      dailyRate: dailyRate ?? this.dailyRate,
      weeklyRate: weeklyRate ?? this.weeklyRate,
      monthlyRate: monthlyRate ?? this.monthlyRate,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Recommendation score for a student (0-100)
  double recommendationScore(dynamic user) {
    double score = 0;
    final studentCity = user?.preferredCity ?? '';
    final studentFacilities = user?.preferredFacilities ?? <String>[];
    final studentBudgetMax = user?.budgetMax ?? 50000;
    final studentGender = user?.preferredGender ?? 'mixed';

    // City match — 35 points
    if (city.toLowerCase() == studentCity.toLowerCase()) score += 35;

    // Facility match — 30 points
    if (studentFacilities.isNotEmpty) {
      final matched = facilities.where((f) => studentFacilities.contains(f)).length;
      score += (matched / studentFacilities.length) * 30;
    }

    // Budget match — 20 points
    if (pricePerMonth <= studentBudgetMax) score += 20;

    // Gender compatibility — 5 points
    if (genderPolicy == 'Both' || genderPolicy == studentGender) score += 5;

    // Advanced student profile matches — up to 10 points
    if (user != null) {
      double prefScore = 0;
      final desc = description.toLowerCase();
      
      // CleanlinessPref match
      if (user.cleanlinessPref == 'high' && rating >= 4.5) prefScore += 2;
      
      // NoisePref match
      if (user.noisePref == 'quiet' && (desc.contains('quiet') || desc.contains('study') || desc.contains('serene'))) {
        prefScore += 2;
      }
      
      // SharingPref match
      if (user.sharingPref == 'single' && (desc.contains('single') || name.toLowerCase().contains('executive') || name.toLowerCase().contains('elite'))) {
        prefScore += 2;
      } else if (user.sharingPref == 'shared' && desc.contains('shared')) {
        prefScore += 2;
      }
      
      // TransportPref match
      if (user.transportPref == 'parking' && (desc.contains('parking') || facilities.contains('Parking'))) {
        prefScore += 2;
      } else if (user.transportPref == 'walking' && (desc.contains('walking') || desc.contains('close') || desc.contains('near'))) {
        prefScore += 2;
      }
      
      // DietPref match
      if (user.dietPref == 'veg' && (desc.contains('veg') || desc.contains('mess') || facilities.contains('Mess / Food'))) {
        prefScore += 2;
      }
      
      score += prefScore;
    }

    return score.clamp(0, 100);
  }
}

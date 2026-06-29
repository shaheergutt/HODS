import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String hostelId;
  final String studentId;
  final String studentName;
  final String studentImageUrl;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.hostelId,
    required this.studentId,
    required this.studentName,
    this.studentImageUrl = '',
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }
    return ReviewModel(
      id: id,
      hostelId: map['hostelId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentImageUrl: map['studentImageUrl'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostelId': hostelId,
      'studentId': studentId,
      'studentName': studentName,
      'studentImageUrl': studentImageUrl,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

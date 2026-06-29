import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String userId;
  final bool isRead;
  final DateTime timestamp;
  final String type; // e.g. 'booking_confirmed', 'roommate_request', 'general'

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
    required this.isRead,
    required this.timestamp,
    this.type = 'general',
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      userId: map['userId'] ?? '',
      isRead: map['isRead'] ?? false,
      timestamp: parseDate(map['timestamp']),
      type: map['type'] ?? 'general',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'userId': userId,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
    };
  }
}

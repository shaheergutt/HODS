import 'package:cloud_firestore/cloud_firestore.dart';

enum RoommateRequestStatus { pending, accepted, declined }

class RoommateRequestModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderImageUrl;
  final String receiverId;
  final String receiverName;
  final String receiverImageUrl;
  final RoommateRequestStatus status;
  final DateTime timestamp;

  const RoommateRequestModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderImageUrl,
    required this.receiverId,
    required this.receiverName,
    required this.receiverImageUrl,
    required this.status,
    required this.timestamp,
  });

  factory RoommateRequestModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }
    return RoommateRequestModel(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderImageUrl: map['senderImageUrl'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      receiverImageUrl: map['receiverImageUrl'] ?? '',
      status: _statusFromString(map['status'] ?? 'pending'),
      timestamp: parseDate(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverImageUrl': receiverImageUrl,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  static RoommateRequestStatus _statusFromString(String s) {
    switch (s) {
      case 'accepted': return RoommateRequestStatus.accepted;
      case 'declined': return RoommateRequestStatus.declined;
      default: return RoommateRequestStatus.pending;
    }
  }
}

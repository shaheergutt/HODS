import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final String studentId;
  final String studentName;
  final String ownerId;
  final String ownerName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int studentUnreadCount;
  final int ownerUnreadCount;
  final bool isStudentTyping;
  final bool isOwnerTyping;

  const ChatModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.ownerId,
    required this.ownerName,
    this.lastMessage = '',
    required this.lastMessageTime,
    this.studentUnreadCount = 0,
    this.ownerUnreadCount = 0,
    this.isStudentTyping = false,
    this.isOwnerTyping = false,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }
    return ChatModel(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      ownerId: map['ownerId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: parseDate(map['lastMessageTime']),
      studentUnreadCount: map['studentUnreadCount'] ?? 0,
      ownerUnreadCount: map['ownerUnreadCount'] ?? 0,
      isStudentTyping: map['isStudentTyping'] ?? false,
      isOwnerTyping: map['isOwnerTyping'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'studentUnreadCount': studentUnreadCount,
      'ownerUnreadCount': ownerUnreadCount,
      'isStudentTyping': isStudentTyping,
      'isOwnerTyping': isOwnerTyping,
    };
  }
}

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String imageUrl;
  final DateTime timestamp;
  final bool isRead;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.imageUrl = '',
    required this.timestamp,
    required this.isRead,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      text: map['text'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      timestamp: parseDate(map['timestamp']),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }
}

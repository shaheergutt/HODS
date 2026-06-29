import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Create or get chat between student and owner
  Future<ChatModel> getOrCreateChat({
    required String studentId,
    required String studentName,
    required String ownerId,
    required String ownerName,
  }) async {
    final query = await _db
        .collection('chats')
        .where('studentId', isEqualTo: studentId)
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return ChatModel.fromMap(query.docs.first.data(), query.docs.first.id);
    }

    final chatId = _uuid.v4();
    final chat = ChatModel(
      id: chatId,
      studentId: studentId,
      studentName: studentName,
      ownerId: ownerId,
      ownerName: ownerName,
      lastMessage: 'Chat started',
      lastMessageTime: DateTime.now(),
      studentUnreadCount: 0,
      ownerUnreadCount: 0,
    );

    await _db.collection('chats').doc(chatId).set(chat.toMap());
    return chat;
  }

  // Get active chats for a user (student or owner)
  Stream<List<ChatModel>> getUserChats(String userId, bool isOwner) {
    final field = isOwner ? 'ownerId' : 'studentId';
    return _db
        .collection('chats')
        .where(field, isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => ChatModel.fromMap(d.data(), d.id))
              .toList();
          list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          return list;
        });
  }

  // Send message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
    String imageUrl = '',
  }) async {
    final messageId = _uuid.v4();
    final timestamp = DateTime.now();

    final msg = MessageModel(
      id: messageId,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      imageUrl: imageUrl,
      timestamp: timestamp,
      isRead: false,
    );

    // Save message inside the subcollection
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set(msg.toMap());

    // Get the current chat document to find who to update unread count for
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    if (chatDoc.exists) {
      final isOwnerSender = senderId == chatDoc.data()?['ownerId'];
      final updateData = <String, dynamic>{
        'lastMessage': imageUrl.isNotEmpty ? '📷 Image' : text,
        'lastMessageTime': Timestamp.fromDate(timestamp),
      };

      if (isOwnerSender) {
        updateData['studentUnreadCount'] = FieldValue.increment(1);
      } else {
        updateData['ownerUnreadCount'] = FieldValue.increment(1);
      }

      await _db.collection('chats').doc(chatId).update(updateData);
    }
  }

  // Mark chat messages as read
  Future<void> markMessagesAsRead(String chatId, String userId, bool isOwner) async {
    final unreadField = isOwner ? 'ownerUnreadCount' : 'studentUnreadCount';
    await _db.collection('chats').doc(chatId).update({unreadField: 0});

    // Mark messages as read in subcollection
    final unreadMessages = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Stream conversation messages
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MessageModel.fromMap(d.data(), d.id))
            .toList());
  }

  // Update typing indicator
  Future<void> setTypingStatus(String chatId, bool isTyping, bool isOwner) async {
    final field = isOwner ? 'isOwnerTyping' : 'isStudentTyping';
    await _db.collection('chats').doc(chatId).update({field: isTyping});
  }
}

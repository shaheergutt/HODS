import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatRoomScreen({super.key, required this.chatId});
  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _chatService = ChatService();
  final _storage = StorageService();
  final _messageCtrl = TextEditingController();
  final _scrollController = ScrollController();
  
  bool _sending = false;
  bool _isTyping = false;
  ChatModel? _chatSession;

  @override
  void initState() {
    super.initState();
    _loadChatSession();
    _messageCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageCtrl.removeListener(_onTextChanged);
    _messageCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatSession() async {
    final snap = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    if (snap.exists && mounted) {
      final chat = ChatModel.fromMap(snap.data()!, snap.id);
      setState(() => _chatSession = chat);

      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        final isOwner = user.role == UserRole.owner;
        await _chatService.markMessagesAsRead(widget.chatId, user.uid, isOwner);
      }
    }
  }

  void _onTextChanged() {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final isOwner = user.role == UserRole.owner;

    final hasText = _messageCtrl.text.isNotEmpty;
    if (hasText != _isTyping) {
      setState(() => _isTyping = hasText);
      _chatService.setTypingStatus(widget.chatId, hasText, isOwner);
    }
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _chatSession == null) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    _messageCtrl.clear();
    final receiverId = user.uid == _chatSession!.studentId ? _chatSession!.ownerId : _chatSession!.studentId;

    try {
      await _chatService.sendMessage(
        chatId: widget.chatId,
        senderId: user.uid,
        receiverId: receiverId,
        text: text,
      );
    } catch (_) {}
  }

  Future<void> _pickAndSendImage() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null || _chatSession == null) return;

    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (img == null) return;

    setState(() => _sending = true);
    final receiverId = user.uid == _chatSession!.studentId ? _chatSession!.ownerId : _chatSession!.studentId;

    try {
      // Upload image using storage service
      final url = await _storage.uploadProfileImageXFile('chats/${widget.chatId}/${const Uuid().v4()}', img);
      await _chatService.sendMessage(
        chatId: widget.chatId,
        senderId: user.uid,
        receiverId: receiverId,
        text: '',
        imageUrl: url,
      );
    } catch (_) {} finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null || _chatSession == null) return const Scaffold(backgroundColor: AppColors.background);
        final isOwner = user.role == UserRole.owner;
        final displayName = isOwner ? _chatSession!.studentName : _chatSession!.ownerName;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(displayName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
                builder: (ctx, snap) {
                  if (snap.hasData && snap.data!.exists) {
                    final c = ChatModel.fromMap(snap.data!.data() as Map<String, dynamic>, snap.data!.id);
                    final otherTyping = isOwner ? c.isStudentTyping : c.isOwnerTyping;
                    if (otherTyping) {
                      return const Text('typing...', style: TextStyle(color: AppColors.primary, fontSize: 11, fontStyle: FontStyle.italic));
                    }
                  }
                  return const Text('Online', style: TextStyle(color: Colors.green, fontSize: 11));
                },
              ),
            ]),
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(user.role == UserRole.owner ? '/owner' : '/student');
                }
              },
            ),
          ),
          body: Column(children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _chatService.getMessages(widget.chatId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data ?? [];
                  return ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = messages[i];
                      final isMe = msg.senderId == user.uid;
                      return _buildMessageBubble(msg, isMe);
                    },
                  );
                },
              ),
            ),
            if (_sending)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: LinearProgressIndicator(color: AppColors.primary)),
            _buildInputRow(),
          ]),
        );
      },
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    final timeStr = DateFormat('h:mm a').format(msg.timestamp);
    final bg = isMe ? AppColors.primary : AppColors.surface;
    final textCol = isMe ? Colors.white : AppColors.textPrimary;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
              ),
              border: isMe ? null : Border.all(color: AppColors.border),
            ),
            child: msg.imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(msg.imageUrl, fit: BoxFit.cover),
                  )
                : Text(msg.text, style: TextStyle(color: textCol, fontSize: 14)),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(timeStr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(Icons.done_all, size: 12, color: msg.isRead ? AppColors.primary : AppColors.textHint),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.image_outlined, color: AppColors.primary), onPressed: _pickAndSendImage),
        Expanded(
          child: TextField(
            controller: _messageCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: const InputDecoration(
              hintText: 'Type your message...',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              border: InputBorder.none,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send, color: AppColors.primary),
          onPressed: _send,
        ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});
  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _chatService = ChatService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) return const Scaffold(backgroundColor: AppColors.background);
        final isOwner = user.role == UserRole.owner;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            title: const Text('Inbox Messages', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search chats by name...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ChatModel>>(
                stream: _chatService.getUserChats(user.uid, isOwner),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading messages: ${snapshot.error}'));
                  }

                  final chats = snapshot.data ?? [];
                  final filtered = chats.where((c) {
                    final name = isOwner ? c.studentName : c.ownerName;
                    return name.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.forum_outlined, size: 72, color: AppColors.textSecondary),
                        SizedBox(height: 12),
                        Text('No conversations yet', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Your messages will appear here', style: TextStyle(color: AppColors.textSecondary)),
                      ]),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final chat = filtered[i];
                      final displayName = isOwner ? chat.studentName : chat.ownerName;
                      final unreadCount = isOwner ? chat.ownerUnreadCount : chat.studentUnreadCount;
                      final isTyping = isOwner ? chat.isStudentTyping : chat.isOwnerTyping;
                      final timeStr = DateFormat('h:mm a').format(chat.lastMessageTime);

                      return ListTile(
                        onTap: () {
                          // Route path based on roles
                          final routePrefix = isOwner ? '/owner' : '/student';
                          context.push('$routePrefix/chat/${chat.id}');
                        },
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(displayName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(displayName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(timeStr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ]),
                        subtitle: Text(
                          isTyping ? 'typing...' : chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isTyping ? AppColors.primary : AppColors.textSecondary, fontSize: 13, fontStyle: isTyping ? FontStyle.italic : FontStyle.normal),
                        ),
                        trailing: unreadCount > 0
                            ? Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_service.dart';
import '../../services/progress/progress_manager.dart';
import 'widgets/ai_status_widget.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

 class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  late final AiService _ai;
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  ProgressManager? _currentProgressManager;
  String? _pendingResponse;

  @override
  void initState() {
    super.initState();
    _ai = AiService();
    _messages.add(ChatMessage(
      text: 'Hello! I\'m HODS Assistant 🏠. I can help you find the perfect hostel, answer questions about bookings, and guide you through our app. How can I help you today?',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _currentProgressManager?.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User profile is loading, please wait...'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final pm = ProgressManager();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _currentProgressManager = pm;
      _isLoading = true;
      _pendingResponse = null;
    });
    _msgController.clear();
    _scrollToBottom();

    try {
      final response = await _ai.sendMessage(text, user.uid, user.role, progressManager: pm);
      if (mounted) {
        setState(() {
          _pendingResponse = response;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Failed to process request.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
          _isLoading = false;
          _currentProgressManager?.dispose();
          _currentProgressManager = null;
          _pendingResponse = null;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _retryMessage(String text) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final pm = ProgressManager();
    setState(() {
      // Clear error indicator messages from the list for a clean flow
      _messages.removeWhere((m) => m.isError && m.text == 'Failed to process request.');
      _currentProgressManager = pm;
      _isLoading = true;
      _pendingResponse = null;
    });
    _scrollToBottom();

    try {
      final response = await _ai.sendMessage(text, user.uid, user.role, progressManager: pm);
      if (mounted) {
        setState(() {
          _pendingResponse = response;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Failed to process request.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
          _isLoading = false;
          _currentProgressManager?.dispose();
          _currentProgressManager = null;
          _pendingResponse = null;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final roleName = user != null ? ' (${user.role.name.toUpperCase()})' : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(user?.role == UserRole.owner ? '/owner' : '/student');
            }
          },
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
            child: const Icon(Icons.support_agent, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('HODS Assistant$roleName', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
              const Text('Powered by Gemini AI', style: TextStyle(color: AppColors.primary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(children: [
        if (_messages.length == 1) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Quick Questions', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                'How to book a hostel?',
                'What is daily booking stay?',
                'Find hostels near FAST',
                'Show my roommates matching compatibility',
              ].map((q) => GestureDetector(
                onTap: () { _msgController.text = q; _sendMessage(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                  child: Text(q, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                ),
              )).toList()),
            ]),
          ),
        ],
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isLoading ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _messages.length && _isLoading) return _buildTypingIndicator();
              final m = _messages[i];
              return _buildMessageBubble(m);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ask me anything about HODS...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildMessageBubble(ChatMessage m) {
    final isUser = m.isUser;
    final timeStr = DateFormat('h:mm a').format(m.timestamp);

    if (m.isError) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.text, style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(timeStr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.error, size: 20),
                onPressed: () {
                  final lastUserMsg = _messages.lastWhere(
                    (msg) => msg.isUser,
                    orElse: () => ChatMessage(text: '', isUser: true, timestamp: DateTime.now()),
                  );
                  if (lastUserMsg.text.isNotEmpty) {
                    _retryMessage(lastUserMsg.text);
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: m.text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message copied to clipboard'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 1),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isUser ? AppColors.primaryGradient : null,
            color: isUser ? null : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
              bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
            ),
            border: isUser ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              _buildMessageText(m.text, isUser),
              const SizedBox(height: 6),
              Text(timeStr, style: TextStyle(color: isUser ? Colors.white70 : AppColors.textHint, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageText(String text, bool isUser) {
    if (isUser) {
      return Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5));
    }

    final lines = text.split('\n');
    final List<Widget> children = [];
    bool inCodeBlock = false;
    List<String> currentCodeBlock = [];

    for (final line in lines) {
      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          children.add(Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              currentCodeBlock.join('\n'),
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ));
          currentCodeBlock.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        currentCodeBlock.add(line);
        continue;
      }

      final isListItem = line.trim().startsWith('* ') || line.trim().startsWith('- ');
      final cleanLine = isListItem ? line.trim().substring(2) : line;

      final spans = _parseLineSpans(cleanLine);

      final textWidget = RichText(
        text: TextSpan(
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
          children: spans,
        ),
      );

      if (isListItem) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
              Expanded(child: textWidget),
            ],
          ),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: textWidget,
        ));
      }
    }

    if (inCodeBlock && currentCodeBlock.isNotEmpty) {
      children.add(Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          currentCodeBlock.join('\n'),
          style: const TextStyle(
            color: AppColors.primaryLight,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      ));
    }

    final referenceWidgets = _buildReferenceActionButtons(text);
    if (referenceWidgets.isNotEmpty) {
      children.add(const SizedBox(height: 10));
      children.add(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: referenceWidgets,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<TextSpan> _parseLineSpans(String line) {
    final List<TextSpan> spans = [];
    final regExp = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    for (final match in regExp.allMatches(line)) {
      if (match.start > start) {
        spans.add(TextSpan(text: line.substring(start, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
      ));
      start = match.end;
    }

    if (start < line.length) {
      spans.add(TextSpan(text: line.substring(start)));
    }

    return spans;
  }

  List<Widget> _buildReferenceActionButtons(String text) {
    final List<Widget> buttons = [];

    // Match standard UUID structure format or alphanumeric IDs of length 20+
    final hostelReg = RegExp(r'(?:hostel|ID|property):\s*([a-zA-Z0-9\-_]{20,})', caseSensitive: false);
    final Set<String> foundHostelIds = {};
    for (final match in hostelReg.allMatches(text)) {
      final id = match.group(1);
      if (id != null) {
        foundHostelIds.add(id);
      }
    }

    for (final id in foundHostelIds) {
      buttons.add(ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          shadowColor: Colors.transparent,
          side: const BorderSide(color: AppColors.primaryLight, width: 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => context.push('/student/hostel/$id'),
        icon: const Icon(Icons.apartment, size: 14, color: AppColors.primaryLight),
        label: Text('Open Hostel ($id)', style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold)),
      ));
    }

    final bookingReg = RegExp(r'booking:\s*([a-zA-Z0-9\-_]{20,})', caseSensitive: false);
    final Set<String> foundBookingIds = {};
    for (final match in bookingReg.allMatches(text)) {
      final id = match.group(1);
      if (id != null) {
        foundBookingIds.add(id);
      }
    }

    for (final id in foundBookingIds) {
      buttons.add(ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success.withValues(alpha: 0.15),
          shadowColor: Colors.transparent,
          side: const BorderSide(color: AppColors.success, width: 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => context.push('/student/bookings'),
        icon: const Icon(Icons.book_online, size: 14, color: AppColors.success),
        label: Text('Open Booking ($id)', style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
      ));
    }

    return buttons;
  }

  Widget _buildTypingIndicator() {
    if (_currentProgressManager != null) {
      return AiStatusWidget(
        progressManager: _currentProgressManager!,
        onCompletionFinished: () {
          if (mounted) {
            setState(() {
              if (_pendingResponse != null) {
                _messages.add(ChatMessage(text: _pendingResponse!, isUser: false, timestamp: DateTime.now()));
              }
              _isLoading = false;
              _currentProgressManager?.dispose();
              _currentProgressManager = null;
              _pendingResponse = null;
            });
            _scrollToBottom();
          }
        },
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _dot(0), const SizedBox(width: 4),
          _dot(200), const SizedBox(width: 4),
          _dot(400),
        ]),
      ),
    );
  }

  Widget _dot(int delay) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 600 + delay),
    builder: (_, v, __) => Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: v), shape: BoxShape.circle),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/roommate_profile_model.dart';
import '../../models/roommate_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/roommate_service.dart';

class RoommateMatchingScreen extends ConsumerStatefulWidget {
  const RoommateMatchingScreen({super.key});
  @override
  ConsumerState<RoommateMatchingScreen> createState() => _RoommateMatchingScreenState();
}

class _RoommateMatchingScreenState extends ConsumerState<RoommateMatchingScreen> {
  final _roommateService = RoommateService();
  final _chatService = ChatService();

  bool _loading = true;
  RoommateProfileModel? _myProfile;
  List<Map<String, dynamic>> _matches = [];
  final Map<String, String> _explanations = {};
  final Map<String, bool> _loadingExplanations = {};

  // Status mapping for roommate requests in list
  final Map<String, RoommateRequestModel?> _requestStatusMap = {};

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final p = await _roommateService.getProfile(user.uid);
    if (p != null) {
      final list = await _roommateService.getMatches(p);
      
      // Load active request statuses for all matches
      for (final item in list) {
        final profile = item['profile'] as RoommateProfileModel;
        final req = await _roommateService.getActiveRequestBetween(user.uid, profile.userId);
        _requestStatusMap[profile.userId] = req;
      }

      if (mounted) {
        setState(() {
          _myProfile = p;
          _matches = list;
          _loading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadExplanation(RoommateProfileModel matchedUser, double score) async {
    if (_explanations.containsKey(matchedUser.userId)) return;
    if (_myProfile == null) return;

    setState(() => _loadingExplanations[matchedUser.userId] = true);
    final explanation = await _roommateService.generateRoommateExplanation(_myProfile!, matchedUser, score);
    if (mounted) {
      setState(() {
        _explanations[matchedUser.userId] = explanation;
        _loadingExplanations[matchedUser.userId] = false;
      });
    }
  }

  Future<void> _sendRequest(RoommateProfileModel matchedUser) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null || _myProfile == null) return;

    try {
      await _roommateService.sendRoommateRequest(
        senderId: user.uid,
        senderName: user.name,
        senderImageUrl: user.profileImageUrl,
        receiverId: matchedUser.userId,
        receiverName: matchedUser.userName,
        receiverImageUrl: matchedUser.profileImageUrl,
      );
      _showSnack('Roommate request sent!', AppColors.success);
      _loadMatches(); // Refresh state
    } catch (e) {
      _showSnack('Failed to send request: $e', AppColors.error);
    }
  }

  Future<void> _handleRequestAction(RoommateRequestModel req, RoommateRequestStatus status) async {
    try {
      await _roommateService.updateRoommateRequestStatus(req.id, status);
      _showSnack('Request ${status.name}!', AppColors.success);
      _loadMatches(); // Refresh state
    } catch (e) {
      _showSnack('Failed to update request: $e', AppColors.error);
    }
  }

  Future<void> _initiateChat(RoommateProfileModel matchedUser) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    // Create a chat session between these two students
    final chat = await _chatService.getOrCreateChat(
      studentId: user.uid,
      studentName: user.name,
      ownerId: matchedUser.userId, // student B acts as recipient
      ownerName: matchedUser.userName,
    );

    if (mounted) {
      context.push('/student/chat/${chat.id}');
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator()));
    }

    if (_myProfile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Roommate Finder'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/student');
              }
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_outline, size: 72, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              const Text('Setup Roommate Profile First', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const Text('You need to configure your roommate profile card before searching.', style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.push('/student/roommate-profile'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Create Profile Card', style: TextStyle(color: Colors.white)),
              ),
            ]),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Find Roommates', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/student');
              }
            },
          ),
          actions: [
            IconButton(icon: const Icon(Icons.edit, color: AppColors.primary), onPressed: () => context.push('/student/roommate-profile')),
          ],
          bottom: const TabBar(
            labelColor: AppColors.primaryLight,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(text: 'Compatible Matches'),
              Tab(text: 'Requests Inbox'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMatchesTab(),
            _buildRequestsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchesTab() {
    if (_matches.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_search_outlined, size: 72, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('No compatible roommates found.', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Try adjusting your daily habit preferences.', style: TextStyle(color: AppColors.textSecondary)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMatches,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _matches.length,
        itemBuilder: (_, i) {
          final item = _matches[i];
          final p = item['profile'] as RoommateProfileModel;
          final score = item['score'] as double;

          final isExpanded = _explanations.containsKey(p.userId);
          final isLoadingEx = _loadingExplanations[p.userId] ?? false;
          final request = _requestStatusMap[p.userId];

          return Card(
            color: AppColors.surface,
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
            child: ExpansionTile(
              onExpansionChanged: (expanded) {
                if (expanded) {
                  _loadExplanation(p, score);
                }
              },
              leading: CircleAvatar(
                backgroundColor: AppColors.primary,
                backgroundImage: p.profileImageUrl.isNotEmpty ? NetworkImage(p.profileImageUrl) : null,
                child: p.profileImageUrl.isEmpty ? Text(p.userName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
              ),
              title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(
                  child: Text(
                    p.userName,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: score >= 75 ? AppColors.primaryGradient : null,
                    color: score < 75 ? AppColors.border : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${score.toStringAsFixed(0)}% Match', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ]),
              subtitle: Text('Age: ${p.age} | University: ${p.university}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(children: [
                          Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                          SizedBox(width: 6),
                          Text('AI Compatibility Match Insights', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                        ]),
                        Text('Budget: PKR ${p.budgetMax}', style: const TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isLoadingEx)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(color: AppColors.primary))
                    else if (isExpanded)
                      Text(_explanations[p.userId]!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4))
                    else
                      const Text('Expand to view compatibility breakdown details...', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: _buildRequestActionButton(p, request),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _initiateChat(p),
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                          label: const Text('Chat Roommate', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestActionButton(RoommateProfileModel matchedUser, RoommateRequestModel? request) {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return const SizedBox();

    if (request == null) {
      return OutlinedButton.icon(
        onPressed: () => _sendRequest(matchedUser),
        icon: const Icon(Icons.person_add_alt_1, color: AppColors.primaryLight, size: 18),
        label: const Text('Send Request', style: TextStyle(color: AppColors.primaryLight)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primaryLight),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    if (request.status == RoommateRequestStatus.pending) {
      final isSender = request.senderId == user.uid;
      if (isSender) {
        return OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_top, color: AppColors.textHint, size: 18),
          label: const Text('Requested', style: TextStyle(color: AppColors.textHint)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _handleRequestAction(request, RoommateRequestStatus.accepted),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Accept', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _handleRequestAction(request, RoommateRequestStatus.declined),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Decline', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        );
      }
    }

    if (request.status == RoommateRequestStatus.accepted) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.handshake, color: AppColors.success, size: 18),
        label: const Text('Connected', style: TextStyle(color: AppColors.success)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.success),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    // Declined request - allow resending
    return OutlinedButton.icon(
      onPressed: () => _sendRequest(matchedUser),
      icon: const Icon(Icons.person_add_alt_1, color: AppColors.primaryLight, size: 18),
      label: const Text('Send Request', style: TextStyle(color: AppColors.primaryLight)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.primaryLight),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildRequestsTab() {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return const SizedBox();

    return StreamBuilder<List<RoommateRequestModel>>(
      stream: _roommateService.getIncomingRequests(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final incoming = snapshot.data ?? [];

        return StreamBuilder<List<RoommateRequestModel>>(
          stream: _roommateService.getOutgoingRequests(user.uid),
          builder: (context, snap2) {
            final outgoing = snap2.data ?? [];

            if (incoming.isEmpty && outgoing.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: AppColors.border),
                    SizedBox(height: 12),
                    Text('No roommate requests found', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (incoming.isNotEmpty) ...[
                  const Text('Incoming Requests', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...incoming.map((req) => _buildRequestCard(req, isIncoming: true)),
                  const SizedBox(height: 24),
                ],
                if (outgoing.isNotEmpty) ...[
                  const Text('Outgoing Requests Sent', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...outgoing.map((req) => _buildRequestCard(req, isIncoming: false)),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRequestCard(RoommateRequestModel req, {required bool isIncoming}) {
    final name = isIncoming ? req.senderName : req.receiverName;
    final img = isIncoming ? req.senderImageUrl : req.receiverImageUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary,
            backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
            child: img.isEmpty ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  'Sent: ${req.timestamp.day}/${req.timestamp.month}/${req.timestamp.year}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          _buildRequestStatusBadge(req, isIncoming),
        ],
      ),
    );
  }

  Widget _buildRequestStatusBadge(RoommateRequestModel req, bool isIncoming) {
    if (req.status == RoommateRequestStatus.pending) {
      if (isIncoming) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: AppColors.success, size: 28),
              onPressed: () => _handleRequestAction(req, RoommateRequestStatus.accepted),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.cancel, color: AppColors.error, size: 28),
              onPressed: () => _handleRequestAction(req, RoommateRequestStatus.declined),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: const Text('PENDING', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold)),
        );
      }
    }

    final color = req.status == RoommateRequestStatus.accepted ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(
        req.status.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/complaint_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';

class ComplaintDetailScreen extends ConsumerStatefulWidget {
  final String complaintId;

  const ComplaintDetailScreen({
    super.key,
    required this.complaintId,
  });

  @override
  ConsumerState<ComplaintDetailScreen> createState() =>
      _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends ConsumerState<ComplaintDetailScreen> {
  final _replyController = TextEditingController();
  final _assignController = TextEditingController();
  final _reopenReasonController = TextEditingController();
  final _studentReplyController = TextEditingController();

  int _selectedRating = 5;
  bool _isLoading = false;
  bool _showRatingForm = false;
  bool _showReopenForm = false;

  @override
  void dispose() {
    _replyController.dispose();
    _assignController.dispose();
    _reopenReasonController.dispose();
    _studentReplyController.dispose();
    super.dispose();
  }

  // ── Owner: reply + change status ────────────────────────────────
  Future<void> _submitReply(
      ComplaintModel complaint, ComplaintStatus status) async {
    final reply = _replyController.text.trim();
    if (reply.isEmpty) {
      _showSnack('Please write a reply before updating.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final svc = ref.read(complaintServiceProvider);
      await svc.replyToComplaint(
        complaintId: complaint.id,
        reply: reply,
        newStatus: status,
      );
      _replyController.clear();
      _showSnack('Reply submitted successfully!');
    } on Exception catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeStatus(
      ComplaintModel complaint, ComplaintStatus status) async {
    setState(() => _isLoading = true);
    try {
      final svc = ref.read(complaintServiceProvider);
      await svc.updateComplaintStatus(complaint.id, status);
      _showSnack('Status updated to ${status.statusLabel}');
    } on Exception catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _closeAndRate(ComplaintModel complaint) async {
    setState(() => _isLoading = true);
    try {
      final svc = ref.read(complaintServiceProvider);
      await svc.closeComplaint(complaint.id, _selectedRating);
      setState(() {
        _showRatingForm = false;
      });
      _showSnack('Thank you for your feedback! Ticket closed.');
    } on Exception catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('Error: $e', style: const TextStyle(color: AppColors.error)),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: Text('User not logged in.')),
          );
        }
        return _buildWithUser(user);
      },
    );
  }

  Widget _buildWithUser(UserModel user) {
    // Use the auth-aware Riverpod provider instead of a raw StreamBuilder.
    // This ensures the stream is cancelled when the user logs out.
    final complaintAsync = ref.watch(complaintStreamProvider(widget.complaintId));

    return complaintAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) {
        final msg = e.toString().contains('permission-denied')
            ? 'Access denied. Please check your login status.'
            : 'Error loading complaint: $e';
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  final userVal = ref.read(currentUserProvider).value;
                  if (userVal?.role == UserRole.admin) {
                    context.go('/admin');
                  } else if (userVal?.role == UserRole.owner) {
                    context.go('/owner');
                  } else {
                    context.go('/student');
                  }
                }
              },
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: 12),
                  Text(msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
          ),
        );
      },
      data: (complaint) {
        if (complaint == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    final userVal = ref.read(currentUserProvider).value;
                    if (userVal?.role == UserRole.admin) {
                      context.go('/admin');
                    } else if (userVal?.role == UserRole.owner) {
                      context.go('/owner');
                    } else {
                      context.go('/student');
                    }
                  }
                },
              ),
            ),
            body: const Center(
              child: Text('Complaint not found.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }

        // Trigger owner viewed timeline event
        if (user.role == UserRole.owner && complaint.hostelOwnerId == user.uid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(complaintServiceProvider).logOwnerViewed(complaint.id);
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(complaint),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(complaint),
                      const SizedBox(height: 20),
                      _buildTimeline(complaint),
                      const SizedBox(height: 20),
                      _buildDescriptionCard(complaint),

                      // Render student response details if they replied
                      if (complaint.studentResponse.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildStudentResponseCard(complaint),
                      ],

                      // Render owner reply details if they replied
                      if (complaint.ownerReply.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildOwnerReplyCard(complaint),
                      ],

                      const SizedBox(height: 20),

                      // Owner Actions
                      if (user.role == UserRole.owner)
                        _buildOwnerActions(complaint, user),

                      // Student Actions: Confirm Resolution
                      if (user.role == UserRole.student &&
                          complaint.status == ComplaintStatus.resolved) ...[
                        _buildStudentResolutionConfirmationCard(complaint),
                        const SizedBox(height: 20),
                      ],

                      // Student Actions: Write Reply (Information Request)
                      if (user.role == UserRole.student &&
                          complaint.status == ComplaintStatus.waitingForStudent) ...[
                        _buildStudentReplyCard(complaint),
                        const SizedBox(height: 20),
                      ],

                      // Show closed display rating
                      if (complaint.status == ComplaintStatus.closed &&
                          complaint.rating > 0) ...[
                        _buildRatingDisplay(complaint),
                        const SizedBox(height: 20),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ComplaintModel complaint) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: AppColors.textPrimary),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            final userVal = ref.read(currentUserProvider).value;
            if (userVal?.role == UserRole.admin) {
              context.go('/admin');
            } else if (userVal?.role == UserRole.owner) {
              context.go('/owner');
            } else {
              context.go('/student');
            }
          }
        },
      ),
      title: const Text('Complaint Details',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _buildStatusBadge(complaint.status),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(ComplaintModel complaint) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCategoryIcon(complaint.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(complaint.title,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(complaint.hostelName,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              _buildPriorityBadge(complaint.priority),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoChip(
                  Icons.person_outline, complaint.studentName),
              _buildInfoChip(Icons.calendar_today_outlined,
                  _formatDate(complaint.createdAt)),
              _buildInfoChip(
                  Icons.category_outlined, complaint.category),
            ],
          ),
        ],
      ),
    );
  }

  // Chronological Timeline Widget
  Widget _buildTimeline(ComplaintModel complaint) {
    if (complaint.timeline.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chronological Timeline',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: complaint.timeline.length,
            itemBuilder: (context, index) {
              final entry = complaint.timeline[index];
              final isLast = index == complaint.timeline.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLast ? AppColors.primary : AppColors.border,
                          border: Border.all(
                            color: isLast ? AppColors.primaryLight : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 38,
                          color: AppColors.border,
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.title,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: isLast ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _actorColor(entry.actor).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.actor.toUpperCase(),
                                style: TextStyle(
                                  color: _actorColor(entry.actor),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.description,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')} - ${_formatDate(entry.timestamp)}',
                          style: const TextStyle(color: AppColors.textHint, fontSize: 9),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _actorColor(String actor) {
    switch (actor.toLowerCase()) {
      case 'student':
        return AppColors.success;
      case 'owner':
        return AppColors.primaryLight;
      case 'admin':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildDescriptionCard(ComplaintModel complaint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Description',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 12),
          Text(complaint.description,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildOwnerReplyCard(ComplaintModel complaint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.reply, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('Latest Owner Reply',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Text(complaint.ownerReply,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5)),
          if (complaint.resolvedAt != null) ...[
            const SizedBox(height: 8),
            Text('Resolved on ${_formatDate(complaint.resolvedAt!)}',
                style: const TextStyle(
                    color: AppColors.textHint, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentResponseCard(ComplaintModel complaint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text('Student Feedback response',
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Text(complaint.studentResponse,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5)),
        ],
      ),
    );
  }

  // ── Owner actions ────────────────────────────────────────────────
  Widget _buildOwnerActions(ComplaintModel complaint, UserModel owner) {
    if (complaint.hostelOwnerId != owner.uid) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Owner Control Board',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        const SizedBox(height: 12),

        // Quick status controls
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (complaint.status == ComplaintStatus.pending ||
                complaint.status == ComplaintStatus.assigned ||
                complaint.status == ComplaintStatus.reopened)
              _buildActionButton(
                label: 'Mark In Progress',
                icon: Icons.play_arrow_rounded,
                color: AppColors.warning,
                onTap: () => _changeStatus(complaint, ComplaintStatus.inProgress),
              ),
            if (complaint.status != ComplaintStatus.resolved &&
                complaint.status != ComplaintStatus.closed &&
                complaint.status != ComplaintStatus.rejected)
              _buildActionButton(
                label: 'Mark Resolved',
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                onTap: () => _changeStatus(complaint, ComplaintStatus.resolved),
              ),
            if (complaint.status != ComplaintStatus.waitingForStudent &&
                complaint.status != ComplaintStatus.closed &&
                complaint.status != ComplaintStatus.resolved)
              _buildActionButton(
                label: 'Request Info',
                icon: Icons.question_mark_rounded,
                color: Colors.purple,
                onTap: () => _changeStatus(complaint, ComplaintStatus.waitingForStudent),
              ),
            if (complaint.status != ComplaintStatus.closed &&
                complaint.status != ComplaintStatus.rejected)
              _buildActionButton(
                label: 'Reject Ticket',
                icon: Icons.cancel_outlined,
                color: AppColors.error,
                onTap: () => _changeStatus(complaint, ComplaintStatus.rejected),
              ),
          ],
        ),

        const SizedBox(height: 20),

        // Assignment Form
        const Text('Assign Ticket',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _assignController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter staff/personnel name...',
                  hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final staff = _assignController.text.trim();
                if (staff.isEmpty) return;
                setState(() => _isLoading = true);
                try {
                  await ref.read(complaintServiceProvider).assignComplaint(
                        complaintId: complaint.id,
                        assignTo: staff,
                      );
                  _assignController.clear();
                  _showSnack('Complaint assigned to $staff');
                } catch (e) {
                  _showSnack('Error: $e', isError: true);
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              child: const Text('Assign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Reply box
        const Text('Write a Reply',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _replyController,
          style: const TextStyle(color: AppColors.textPrimary),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Explain actions taken or timeline...',
            hintStyle:
                const TextStyle(color: AppColors.textHint, fontSize: 13),
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Send Reply',
                icon: Icons.send_rounded,
                color: AppColors.info,
                onTap: () => _submitReply(complaint, complaint.status),
              ),
            ),
            if (complaint.status != ComplaintStatus.resolved) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  label: 'Reply & Resolve',
                  icon: Icons.done_all,
                  color: AppColors.success,
                  onTap: () =>
                      _submitReply(complaint, ComplaintStatus.resolved),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Student: Confirmation resolution Yes/No card ─────────────────
  Widget _buildStudentResolutionConfirmationCard(ComplaintModel complaint) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.help_outline, color: AppColors.primary, size: 36),
          const SizedBox(height: 12),
          const Text('Confirm Complaint Resolution',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 6),
          const Text(
            'Your hostel owner marked this issue as resolved. Is the problem fixed?',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    setState(() {
                      _showRatingForm = true;
                      _showReopenForm = false;
                    });
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('YES', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    setState(() {
                      _showRatingForm = false;
                      _showReopenForm = true;
                    });
                  },
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('NO', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          if (_showRatingForm) ...[
            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 10),
            const Text('Rate Complaint Handling', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedRating = i + 1);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < _selectedRating ? Icons.star : Icons.star_border,
                      color: AppColors.warning,
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _closeAndRate(complaint),
                child: const Text('Submit & Close Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          if (_showReopenForm) ...[
            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 10),
            const Text('Explain what is still broken', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: _reopenReasonController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter reason for reopening ticket...',
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                filled: true,
                fillColor: AppColors.inputFill,
                contentPadding: const EdgeInsets.all(12),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final reason = _reopenReasonController.text.trim();
                  if (reason.isEmpty) return;
                  setState(() => _isLoading = true);
                  try {
                    await ref.read(complaintServiceProvider).rejectResolution(
                          complaintId: complaint.id,
                          reason: reason,
                        );
                    _reopenReasonController.clear();
                    setState(() {
                      _showReopenForm = false;
                    });
                    _showSnack('Resolution rejected. Ticket reopened and escalated.');
                  } catch (e) {
                    _showSnack('Error: $e', isError: true);
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                child: const Text('Reopen Complaint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Student: write reply for info requests ──────────────────────
  Widget _buildStudentReplyCard(ComplaintModel complaint) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Information Requested', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          const Text(
            'The owner has requested details on this complaint. Please reply below:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _studentReplyController,
            style: const TextStyle(color: AppColors.textPrimary),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter requested details...',
              hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
              filled: true,
              fillColor: AppColors.inputFill,
              contentPadding: const EdgeInsets.all(12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final text = _studentReplyController.text.trim();
                if (text.isEmpty) return;
                setState(() => _isLoading = true);
                try {
                  await ref.read(complaintServiceProvider).studentReply(
                        complaintId: complaint.id,
                        response: text,
                      );
                  _studentReplyController.clear();
                  _showSnack('Response submitted to owner.');
                } catch (e) {
                  _showSnack('Error: $e', isError: true);
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              child: const Text('Submit Response', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDisplay(ComplaintModel complaint) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Text('Your satisfaction rating:',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 10),
          ...List.generate(
            5,
            (i) => Icon(
              i < complaint.rating ? Icons.star : Icons.star_border,
              color: AppColors.warning,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────
  Widget _buildStatusBadge(ComplaintStatus status) {
    final map = {
      ComplaintStatus.pending: (AppColors.info, 'Pending'),
      ComplaintStatus.assigned: (AppColors.primaryLight, 'Assigned'),
      ComplaintStatus.inProgress: (AppColors.warning, 'In Progress'),
      ComplaintStatus.waitingForStudent: (Colors.purple, 'Waiting for Student'),
      ComplaintStatus.resolved: (AppColors.success, 'Resolved'),
      ComplaintStatus.closed: (AppColors.textSecondary, 'Closed'),
      ComplaintStatus.rejected: (AppColors.error, 'Rejected'),
      ComplaintStatus.reopened: (Colors.deepOrange, 'Reopened'),
    };
    final (color, label) = map[status]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPriorityBadge(ComplaintPriority priority) {
    final map = {
      ComplaintPriority.low: (AppColors.success, 'Low'),
      ComplaintPriority.medium: (AppColors.info, 'Medium'),
      ComplaintPriority.high: (AppColors.warning, 'High'),
      ComplaintPriority.urgent: (AppColors.error, 'Urgent'),
    };
    final (color, label) = map[priority]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCategoryIcon(String category) {
    IconData icon;
    Color color;
    switch (category.toLowerCase()) {
      case 'electricity':
        icon = Icons.bolt;
        color = Colors.amber;
        break;
      case 'water':
        icon = Icons.water_drop;
        color = AppColors.waterColor;
        break;
      case 'internet':
        icon = Icons.wifi;
        color = AppColors.wifiColor;
        break;
      case 'mess':
        icon = Icons.restaurant;
        color = AppColors.mealsColor;
        break;
      case 'security':
        icon = Icons.security;
        color = AppColors.securityColor;
        break;
      case 'maintenance':
        icon = Icons.build_circle;
        color = AppColors.parkingColor;
        break;
      case 'cleanliness':
        icon = Icons.cleaning_services;
        color = AppColors.acColor;
        break;
      default:
        icon = Icons.assignment_outlined;
        color = AppColors.primaryLight;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label,
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/complaint_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';

class ComplaintListScreen extends ConsumerStatefulWidget {
  const ComplaintListScreen({super.key});

  @override
  ConsumerState<ComplaintListScreen> createState() =>
      _ComplaintListScreenState();
}

class _ComplaintListScreenState extends ConsumerState<ComplaintListScreen> {
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
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.error))),
      ),
      data: (user) {
        if (user == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline,
                      color: AppColors.textSecondary, size: 48),
                  const SizedBox(height: 12),
                  const Text('Please log in to view complaints.',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    onPressed: () => context.go('/login'),
                    child: const Text('Log In',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildScaffold(context, user);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, UserModel user) {
    final isStudent = user.role == UserRole.student;
    final complaintsAsync = isStudent
        ? ref.watch(studentComplaintsProvider(user.uid))
        : ref.watch(ownerComplaintsProvider(user.uid));

    return complaintsAsync.when(
      loading: () => Scaffold(
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
                context.go(user.role == UserRole.owner ? '/owner' : '/student');
              }
            },
          ),
          title: Text(isStudent ? 'My Complaints' : 'Hostel Complaints',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
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
                context.go(user.role == UserRole.owner ? '/owner' : '/student');
              }
            },
          ),
          title: Text(isStudent ? 'My Complaints' : 'Hostel Complaints',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        body: _buildErrorState(e.toString()),
      ),
      data: (complaints) {
        return _RoleBasedComplaintList(
          user: user,
          complaints: complaints,
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    String friendly = message;
    if (message.contains('permission-denied')) {
      friendly = 'Access denied. Please check your login status.';
    } else if (message.contains('network') || message.contains('unavailable')) {
      friendly = 'No internet connection. Please try again.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(friendly,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _RoleBasedComplaintList extends ConsumerStatefulWidget {
  final UserModel user;
  final List<ComplaintModel> complaints;

  const _RoleBasedComplaintList({
    required this.user,
    required this.complaints,
  });

  @override
  ConsumerState<_RoleBasedComplaintList> createState() =>
      _RoleBasedComplaintListState();
}

class _RoleBasedComplaintListState
    extends ConsumerState<_RoleBasedComplaintList>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> _tabs;

  @override
  void initState() {
    super.initState();
    if (widget.user.role == UserRole.student) {
      _tabs = [
        'All',
        'Pending',
        'In Progress',
        'Waiting Response',
        'Resolved',
        'Closed'
      ];
    } else {
      _tabs = [
        'All',
        'Pending',
        'In Progress',
        'Waiting Response',
        'Resolved',
        'Closed',
        'High Priority'
      ];
    }
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<ComplaintModel> _filterComplaints(String tab) {
    final list = widget.complaints;
    switch (tab) {
      case 'All':
        return list;
      case 'Pending':
        return list
            .where((c) =>
                c.status == ComplaintStatus.pending ||
                c.status == ComplaintStatus.reopened)
            .toList();
      case 'In Progress':
        return list
            .where((c) =>
                c.status == ComplaintStatus.inProgress ||
                c.status == ComplaintStatus.assigned)
            .toList();
      case 'Waiting Response':
        return list
            .where((c) => c.status == ComplaintStatus.waitingForStudent)
            .toList();
      case 'Resolved':
        return list
            .where((c) => c.status == ComplaintStatus.resolved)
            .toList();
      case 'Closed':
        return list
            .where((c) =>
                c.status == ComplaintStatus.closed ||
                c.status == ComplaintStatus.rejected)
            .toList();
      case 'High Priority':
        return list
            .where((c) =>
                c.priority == ComplaintPriority.high ||
                c.priority == ComplaintPriority.urgent)
            .toList();
      default:
        return list;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = widget.user.role == UserRole.student;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(widget.user.role == UserRole.owner ? '/owner' : '/student');
            }
          },
        ),
        title: Text(
          isStudent ? 'My Complaints' : 'Hostel Complaints',
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) {
          final filtered = _filterComplaints(tab);
          return _buildList(filtered, widget.user);
        }).toList(),
      ),
      floatingActionButton: isStudent
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: () => context.push('/complaints/new'),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('File Complaint',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildList(List<ComplaintModel> complaints, UserModel user) {
    if (complaints.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          if (user.role == UserRole.student) {
            ref.invalidate(studentComplaintsProvider(user.uid));
          } else {
            ref.invalidate(ownerComplaintsProvider(user.uid));
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _buildEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Nothing here',
              subtitle: 'No complaints in this category.',
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        if (user.role == UserRole.student) {
          ref.invalidate(studentComplaintsProvider(user.uid));
        } else {
          ref.invalidate(ownerComplaintsProvider(user.uid));
        }
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: complaints.length,
        itemBuilder: (_, i) => _ComplaintCard(
          complaint: complaints[i],
          currentUser: user,
          onTap: () {
            final base = user.role == UserRole.owner
                ? '/owner/complaints'
                : '/complaints';
            context.push('$base/${complaints[i].id}');
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 40, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Complaint Card ───────────────────────────────────────────────────
class _ComplaintCard extends StatelessWidget {
  final ComplaintModel complaint;
  final UserModel currentUser;
  final VoidCallback onTap;

  const _ComplaintCard({
    required this.complaint,
    required this.currentUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _categoryIcon(complaint.category),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(complaint.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(complaint.hostelName,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statusBadge(complaint.status),
                      const SizedBox(height: 4),
                      _priorityDot(complaint.priority),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(complaint.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${complaint.createdAt.day}/${complaint.createdAt.month}/${complaint.createdAt.year}',
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 11),
                  ),
                  Row(
                    children: [
                      if (complaint.ownerReply.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.reply, size: 14,
                              color: AppColors.primaryLight),
                        ),
                      if (complaint.rating > 0)
                        Row(
                          children: List.generate(
                            complaint.rating,
                            (_) => const Icon(Icons.star,
                                size: 12, color: AppColors.warning),
                          ),
                        ),
                      if (currentUser.role == UserRole.student &&
                          complaint.status == ComplaintStatus.resolved &&
                          complaint.rating == 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Confirm Resolution',
                              style: TextStyle(
                                  color: AppColors.warning, fontSize: 10)),
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios,
                          size: 12, color: AppColors.textHint),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryIcon(String category) {
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
        color = AppColors.laundryColor;
        break;
      default:
        icon = Icons.assignment_outlined;
        color = AppColors.primaryLight;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: color),
    );
  }

  Widget _statusBadge(ComplaintStatus status) {
    final map = {
      ComplaintStatus.pending: (AppColors.info, 'Pending'),
      ComplaintStatus.assigned: (AppColors.primaryLight, 'Assigned'),
      ComplaintStatus.inProgress: (AppColors.warning, 'In Progress'),
      ComplaintStatus.waitingForStudent: (Colors.purple, 'Waiting Response'),
      ComplaintStatus.resolved: (AppColors.success, 'Resolved'),
      ComplaintStatus.closed: (AppColors.textSecondary, 'Closed'),
      ComplaintStatus.rejected: (AppColors.error, 'Rejected'),
      ComplaintStatus.reopened: (Colors.deepOrange, 'Reopened'),
    };
    final (color, label) = map[status]!;
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

  Widget _priorityDot(ComplaintPriority priority) {
    final map = {
      ComplaintPriority.low: AppColors.success,
      ComplaintPriority.medium: AppColors.info,
      ComplaintPriority.high: AppColors.warning,
      ComplaintPriority.urgent: AppColors.error,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: map[priority]!),
        ),
        const SizedBox(width: 4),
        Text(priority.priorityLabel,
            style: TextStyle(color: map[priority]!, fontSize: 9)),
      ],
    );
  }
}

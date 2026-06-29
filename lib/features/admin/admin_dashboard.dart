import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/shimmer_loading_widget.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});
  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  Map<String, int> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await FirestoreService().getAdminStats();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          backgroundColor: AppColors.background,
          floating: true,
          automaticallyImplyLeading: false,
          title: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 22)),
            const SizedBox(width: 10),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Admin Dashboard', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              Text('HODS Control Panel', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ]),
          actions: [
            IconButton(icon: const Icon(Icons.logout, color: AppColors.error), onPressed: () async { await FirestoreService().signOut(); if (context.mounted) context.go('/'); }),
          ],
        ),
        if (_loading)
          SliverToBoxAdapter(
            child: SafeArea(child: SingleChildScrollView(child: ShimmerLoadingWidget.dashboardSkeleton())),
          )
        else ...[
          SliverToBoxAdapter(child: _buildStatsGrid()),
          SliverToBoxAdapter(child: _buildMenuItems(context)),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
    );
  }

  Widget _buildStatsGrid() {
    final cards = [
      {'label': 'Total Users', 'value': _stats['totalUsers'] ?? 0, 'icon': Icons.people, 'color': AppColors.primary},
      {'label': 'Students', 'value': _stats['totalStudents'] ?? 0, 'icon': Icons.school, 'color': AppColors.info},
      {'label': 'Owners', 'value': _stats['totalOwners'] ?? 0, 'icon': Icons.business, 'color': AppColors.success},
      {'label': 'Pending Owners', 'value': _stats['pendingOwners'] ?? 0, 'icon': Icons.hourglass_top, 'color': AppColors.warning},
      {'label': 'Total Hostels', 'value': _stats['totalHostels'] ?? 0, 'icon': Icons.home_work, 'color': AppColors.primary},
      {'label': 'Pending Hostels', 'value': _stats['pendingHostels'] ?? 0, 'icon': Icons.pending, 'color': AppColors.warning},
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85),
        itemCount: cards.length,
        itemBuilder: (_, i) {
          final c = cards[i];
          final color = c['color'] as Color;
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.3))),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(c['icon'] as IconData, color: color, size: 24),
              const SizedBox(height: 4),
              Text((c['value'] as int).toString(), style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(c['label'] as String, style: TextStyle(color: color, fontSize: 10), textAlign: TextAlign.center),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    final items = [
      {'icon': Icons.verified_user, 'title': 'Approve Owners', 'subtitle': 'Review and approve hostel owner applications', 'route': '/admin/approve-owners', 'color': AppColors.warning},
      {'icon': Icons.analytics, 'title': 'System Analytics', 'subtitle': 'View monthly revenue and booking insights', 'route': '/admin/analytics', 'color': AppColors.success},
      {'icon': Icons.home_work, 'title': 'Manage Hostels', 'subtitle': 'View, approve, or remove hostel listings', 'route': '/admin/manage-hostels', 'color': AppColors.primary},
      {'icon': Icons.people, 'title': 'Manage Users', 'subtitle': 'View all students and owners on the platform', 'route': '/admin/manage-users', 'color': AppColors.info},
      {'icon': Icons.report_problem, 'title': 'Manage Complaints', 'subtitle': 'Monitor and resolve platform complaints', 'route': '/admin/complaints', 'color': AppColors.error},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: items.map((item) {
        final color = item['color'] as Color;
        return GestureDetector(
          onTap: () => context.push(item['route'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Icon(item['icon'] as IconData, color: color, size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['title'] as String, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(item['subtitle'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ])),
              const Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 14),
            ]),
          ),
        );
      }).toList()),
    );
  }
}

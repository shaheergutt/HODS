import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hostel_provider.dart';
import '../../widgets/hostel_card.dart';
import '../../widgets/common/shimmer_loading_widget.dart';
import '../../widgets/common/error_state_widget.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final hostelsAsync = ref.watch(allHostelsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: userAsync.when(
        loading: () => Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(child: SingleChildScrollView(child: ShimmerLoadingWidget.dashboardSkeleton())),
        ),
        error: (e, _) => Scaffold(
          backgroundColor: AppColors.background,
          body: ErrorStateWidget(
            message: 'Failed to load user profile: $e',
            onRetry: () => ref.invalidate(currentUserProvider),
          ),
        ),
        data: (user) {
          if (user == null) return const SizedBox();
          return CustomScrollView(
            slivers: [
              _buildAppBar(context, ref, user),
              SliverToBoxAdapter(child: _buildGreeting(user)),
              SliverToBoxAdapter(child: _buildSearchBar(context)),
              SliverToBoxAdapter(child: _buildQuickActions(context)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recommended for You',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => context.push('/student/search'),
                        child: const Text('See All', style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
              ),
              hostelsAsync.when(
                loading: () => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildShimmerCard(),
                    childCount: 3,
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: ErrorStateWidget(
                      message: 'Failed to load hostels: $e',
                      onRetry: () => ref.invalidate(allHostelsProvider),
                    ),
                  ),
                ),
                data: (hostels) {
                  final approved = hostels.where((h) => h.isApproved).toList();
                  final recommended = user.preferredCity != null
                      ? (approved
                          .where((h) =>
                              h.city.toLowerCase() == user.preferredCity!.toLowerCase())
                          .toList()
                        ..sort((a, b) => b.recommendationScore(user).compareTo(a.recommendationScore(user))))
                      : approved;

                  if (recommended.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
                              const SizedBox(height: 12),
                              const Text('No hostels available in your area',
                                  style: TextStyle(color: AppColors.textSecondary)),
                              TextButton(
                                  onPressed: () => context.push('/student/search'),
                                  child: const Text('Search All Hostels')),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => HostelCard(hostel: recommended[i], currentUser: user),
                        childCount: recommended.length > 10 ? 10 : recommended.length,
                      ),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, WidgetRef ref, UserModel user) {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      floating: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.favorite_border, color: AppColors.textPrimary),
          onPressed: () => context.push('/student/favorites'),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
          onPressed: () => context.push('/student/notifications'),
        ),
        GestureDetector(
          onTap: () => context.push('/student/profile'),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              backgroundImage: user.profileImageUrl.isNotEmpty
                  ? CachedNetworkImageProvider(user.profileImageUrl)
                  : null,
              child: user.profileImageUrl.isEmpty
                  ? Text(user.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting(UserModel user) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$greeting 👋',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(user.name,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
          Text('Find your perfect hostel in ${user.preferredCity ?? "Pakistan"}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: GestureDetector(
        onTap: () => context.push('/student/search'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: AppColors.textSecondary),
              SizedBox(width: 10),
              Text('Search hostels by city or name...',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.search, 'label': 'Search', 'route': '/student/search'},
      {'icon': Icons.book_online, 'label': 'My Bookings', 'route': '/student/bookings'},
      {'icon': Icons.support_agent, 'label': 'AI Chat', 'route': '/student/chat'},
      {'icon': Icons.map_outlined, 'label': 'Map Tracker', 'route': '/student/map'},
      {'icon': Icons.people_outline, 'label': 'Roommates', 'route': '/student/roommate-matching'},
      {'icon': Icons.report_problem_outlined, 'label': 'Complaints', 'route': '/complaints'},
      {'icon': Icons.tune_outlined, 'label': 'Preferences', 'route': '/student/preferences'},
      {'icon': Icons.person_outline, 'label': 'Profile', 'route': '/student/profile'},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final a = actions[index];
          return GestureDetector(
            onTap: () => context.push(a['route'] as String),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(a['icon'] as IconData, color: AppColors.primary, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  a['label'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.border,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: 200,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        currentIndex: 0,
        onTap: (i) {
          switch (i) {
            case 0: context.go('/student'); break;
            case 1: context.push('/student/search'); break;
            case 2: context.push('/student/bookings'); break;
            case 3: context.push('/student/chat'); break;
            case 4: context.push('/student/profile'); break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.book_online), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.support_agent), label: 'AI Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

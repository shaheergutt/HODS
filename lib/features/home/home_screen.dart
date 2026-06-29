import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/hostel_provider.dart';
import '../../widgets/hostel_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostelsAsync = ref.watch(allHostelsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: Stack(children: [
                  Positioned(top: -30, right: -30,
                    child: Container(width: 200, height: 200,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05)))),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Text('HODS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                          TextButton(
                            onPressed: () => context.go('/role-select'),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            child: const Text('Sign Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                        ]),
                        const SizedBox(height: 16),
                        const Text('Find Your Perfect\nStudent Hostel',
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // Navigation tabs
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                _NavTab(label: 'Home', icon: Icons.home_rounded, onTap: () {}),
                _NavTab(label: 'About', icon: Icons.info_outline, onTap: () => context.go('/about')),
                _NavTab(label: 'Contact', icon: Icons.contact_mail_outlined, onTap: () => context.go('/contact')),
              ]),
            ),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Featured Hostels',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('Browse verified hostels across Pakistan',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ),
          ),

          // Hostels list
          hostelsAsync.when(
            data: (hostels) => SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => HostelCard(hostel: hostels[i]),
                  childCount: hostels.length,
                ),
              ),
            ),
            loading: () => SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => _ShimmerCard(),
                  childCount: 3,
                ),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Error loading hostels: $e',
                  style: const TextStyle(color: AppColors.error)),
              )),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                const Text('List Your Hostel on HODS',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Join hundreds of verified hostel owners and reach thousands of students.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/register/owner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Register as Owner', style: TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _NavTab({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.cardColor,
      highlightColor: AppColors.border,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 280,
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

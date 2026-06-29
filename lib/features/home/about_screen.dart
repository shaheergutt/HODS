import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('About HODS',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.home_work_rounded, size: 56, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text('HODS', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    icon: Icons.info_outline,
                    title: 'What is HODS?',
                    content:
                        'HODS (Hostel Online Distribution System) is a smart hostel booking platform that connects students with verified hostel owners across Pakistan. We make finding the perfect accommodation simple, safe, and efficient.',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    icon: Icons.track_changes,
                    title: 'Our Mission',
                    content:
                        'To revolutionize the student accommodation experience by providing a transparent, AI-powered platform where students can find hostels that match their preferences, and owners can manage their properties effortlessly.',
                  ),
                  const SizedBox(height: 20),
                  const Text('Key Features',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._features.map((f) => _buildFeatureItem(f['icon'] as IconData, f['title']!, f['desc']!)),
                  const SizedBox(height: 20),
                  _buildSection(
                    icon: Icons.verified_user,
                    title: 'Verified Owners',
                    content:
                        'Every hostel owner on HODS goes through a rigorous verification process. Our super admin reviews and approves owner registrations, assigns license numbers, and ensures quality and safety standards are met.',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    icon: Icons.school,
                    title: 'For Students',
                    content:
                        'Built specifically with students in mind — search by location, filter by facilities and budget, and get AI-powered hostel recommendations based on your profile and preferences.',
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.code, color: Colors.white, size: 32),
                        SizedBox(height: 8),
                        Text('Version 1.0.0',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Built with Flutter & Firebase',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('© 2024 HODS. All rights reserved.',
                            style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<Map<String, dynamic>> _features = [
    {'icon': Icons.search, 'title': 'Smart Search', 'desc': 'Find hostels by location, city, and facilities'},
    {'icon': Icons.psychology, 'title': 'AI Recommendations', 'desc': 'Personalized hostel suggestions based on your profile'},
    {'icon': Icons.verified, 'title': 'Verified Listings', 'desc': 'All hostels are reviewed and approved by admins'},
    {'icon': Icons.support_agent, 'title': 'AI Chatbot', 'desc': '24/7 customer support powered by Google Gemini'},
    {'icon': Icons.book_online, 'title': 'Easy Booking', 'desc': 'Book your hostel in just a few taps'},
    {'icon': Icons.star, 'title': 'Reviews & Ratings', 'desc': 'Real student reviews to help you decide'},
  ];

  Widget _buildFeatureItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(desc,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required String content}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}

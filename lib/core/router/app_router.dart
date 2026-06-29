// ignore: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/role_selection_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/student_register_screen.dart';
import '../../features/auth/owner_register_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/about_screen.dart';
import '../../features/home/contact_screen.dart';
import '../../features/student/student_dashboard.dart';
import '../../features/student/search_screen.dart';
import '../../features/student/hostel_detail_screen.dart';
import '../../features/student/booking_screen.dart';
import '../../features/student/my_bookings_screen.dart';
import '../../features/student/ai_chat_screen.dart';
import '../../features/student/student_profile_screen.dart';
import '../../features/student/hostel_map_screen.dart';
import '../../features/student/user_preferences_screen.dart';
import '../../features/student/roommate_setup_screen.dart';
import '../../features/student/roommate_matching_screen.dart';
import '../../features/student/favorites_screen.dart';
import '../../features/student/notifications_screen.dart';
import '../../features/chat/chat_list_screen.dart';
import '../../features/chat/chat_room_screen.dart';
import '../../features/complaints/complaint_list_screen.dart';
import '../../features/complaints/complaint_form_screen.dart';
import '../../features/complaints/complaint_detail_screen.dart';
import '../../features/owner/owner_dashboard.dart';
import '../../features/owner/add_hostel_screen.dart';
import '../../features/owner/edit_hostel_screen.dart';
import '../../features/owner/owner_bookings_screen.dart';
import '../../features/owner/owner_profile_screen.dart';
import '../../features/owner/vacancy_forecast_screen.dart';
import '../../features/owner/qr_scanner_screen.dart';
import '../../features/owner/room_list_screen.dart';
import '../../features/owner/add_edit_room_screen.dart';
import '../../features/admin/admin_dashboard.dart';
import '../../features/admin/approve_owners_screen.dart';
import '../../features/admin/manage_users_screen.dart';
import '../../features/admin/admin_analytics_screen.dart';
import '../../features/admin/manage_hostels_screen.dart';
import '../../features/admin/admin_complaints_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final user = authState.value;
      final location = state.matchedLocation;

      final publicRoutes = [
        '/splash', '/onboarding', '/role-select',
        '/login', '/register/student', '/register/owner',
        '/home', '/about', '/contact',
      ];

      final isPublic =
          publicRoutes.any((r) => location == r || location.startsWith(r));

      if (user == null) {
        if (!isPublic) return '/home';
        return null;
      }

      // Redirect from auth pages to dashboard
      if (location == '/login' ||
          location == '/role-select' ||
          location.startsWith('/register')) {
        return _dashboardRoute(user);
      }

      // Role-based guarding
      if (location.startsWith('/student') && user.role != UserRole.student) {
        return _dashboardRoute(user);
      }
      if (location.startsWith('/owner') && user.role != UserRole.owner) {
        return _dashboardRoute(user);
      }
      if (location.startsWith('/admin') && user.role != UserRole.admin) {
        return _dashboardRoute(user);
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/role-select', builder: (_, __) => const RoleSelectionScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register/student', builder: (_, __) => const StudentRegisterScreen()),
      GoRoute(path: '/register/owner', builder: (_, __) => const OwnerRegisterScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/contact', builder: (_, __) => const ContactScreen()),

      // Complaints — shared routes (student & owner both use these)
      GoRoute(path: '/complaints', builder: (_, __) => const ComplaintListScreen()),
      GoRoute(path: '/complaints/new', builder: (_, __) => const ComplaintFormScreen()),
      GoRoute(
        path: '/complaints/:id',
        builder: (_, state) =>
            ComplaintDetailScreen(complaintId: state.pathParameters['id']!),
      ),

      // Student
      GoRoute(path: '/student', builder: (_, __) => const StudentDashboard()),
      GoRoute(path: '/student/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/student/map', builder: (_, __) => const HostelMapScreen()),
      GoRoute(path: '/student/preferences', builder: (_, __) => const UserPreferencesScreen()),
      GoRoute(path: '/student/roommate-profile', builder: (_, __) => const RoommateSetupScreen()),
      GoRoute(path: '/student/roommate-matching', builder: (_, __) => const RoommateMatchingScreen()),
      GoRoute(path: '/student/chat-inbox', builder: (_, __) => const ChatListScreen()),
      GoRoute(
        path: '/student/chat/:chatId',
        builder: (_, state) => ChatRoomScreen(chatId: state.pathParameters['chatId']!),
      ),
      GoRoute(
        path: '/student/hostel/:id',
        builder: (_, state) =>
            HostelDetailScreen(hostelId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/student/book/:hostelId',
        builder: (_, state) =>
            BookingScreen(hostelId: state.pathParameters['hostelId']!),
      ),
      GoRoute(path: '/student/bookings', builder: (_, __) => const MyBookingsScreen()),
      GoRoute(path: '/student/chat', builder: (_, __) => const AiChatScreen()),
      GoRoute(path: '/student/profile', builder: (_, __) => const StudentProfileScreen()),
      GoRoute(path: '/student/favorites', builder: (_, __) => const FavoritesScreen()),
      GoRoute(path: '/student/notifications', builder: (_, __) => const NotificationsScreen()),

      // Owner
      GoRoute(path: '/owner', builder: (_, __) => const OwnerDashboard()),
      GoRoute(path: '/owner/add-hostel', builder: (_, __) => const AddHostelScreen()),
      GoRoute(
        path: '/owner/edit-hostel/:id',
        builder: (_, state) =>
            EditHostelScreen(hostelId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/owner/hostel/:hostelId/rooms',
        builder: (_, state) => RoomListScreen(hostelId: state.pathParameters['hostelId']!),
      ),
      GoRoute(
        path: '/owner/hostel/:hostelId/rooms/add',
        builder: (_, state) => AddEditRoomScreen(hostelId: state.pathParameters['hostelId']!),
      ),
      GoRoute(
        path: '/owner/hostel/:hostelId/rooms/edit/:roomId',
        builder: (_, state) => AddEditRoomScreen(
          hostelId: state.pathParameters['hostelId']!,
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/owner/chat/:chatId',
        builder: (_, state) => ChatRoomScreen(chatId: state.pathParameters['chatId']!),
      ),
      GoRoute(path: '/owner/bookings', builder: (_, __) => const OwnerBookingsScreen()),
      GoRoute(path: '/owner/profile', builder: (_, __) => const OwnerProfileScreen()),
      GoRoute(path: '/owner/forecast', builder: (_, __) => const VacancyForecastScreen()),
      GoRoute(path: '/owner/qr-scanner', builder: (_, __) => const QrScannerScreen()),
      GoRoute(path: '/owner/complaints', builder: (_, __) => const ComplaintListScreen()),
      GoRoute(
        path: '/owner/complaints/:id',
        builder: (_, state) =>
            ComplaintDetailScreen(complaintId: state.pathParameters['id']!),
      ),

      // Admin
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
      GoRoute(path: '/admin/approve-owners', builder: (_, __) => const ApproveOwnersScreen()),
      GoRoute(path: '/admin/manage-users', builder: (_, __) => const ManageUsersScreen()),
      GoRoute(path: '/admin/manage-hostels', builder: (_, __) => const ManageHostelsScreen()),
      GoRoute(path: '/admin/analytics', builder: (_, __) => const AdminAnalyticsScreen()),
      GoRoute(path: '/admin/complaints', builder: (_, __) => const AdminComplaintsScreen()),
      GoRoute(
        path: '/admin/complaints/:id',
        builder: (_, state) =>
            ComplaintDetailScreen(complaintId: state.pathParameters['id']!),
      ),
    ],
  );
});

String _dashboardRoute(UserModel user) {
  switch (user.role) {
    case UserRole.student:
      return '/student';
    case UserRole.owner:
      return '/owner';
    case UserRole.admin:
      return '/admin';
  }
}

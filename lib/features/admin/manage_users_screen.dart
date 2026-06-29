import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class ManageUsersScreen extends ConsumerStatefulWidget {
  const ManageUsersScreen({super.key});
  @override
  ConsumerState<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends ConsumerState<ManageUsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<UserModel> _students = [];
  List<UserModel> _owners = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final fs = FirestoreService();
    final students = await fs.getAllStudents();
    final owners = await fs.getAllOwners();
    if (mounted) setState(() { _students = students; _owners = owners; _loading = false; });
  }

  List<UserModel> _filter(List<UserModel> users) {
    if (_search.isEmpty) return users;
    return users.where((u) => u.name.toLowerCase().contains(_search.toLowerCase()) || u.email.toLowerCase().contains(_search.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Manage Users', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin');
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  filled: true, fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: [Tab(text: 'Students (${_students.length})'), Tab(text: 'Owners (${_owners.length})')],
            ),
          ]),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabCtrl, children: [
              _buildUserList(_filter(_students), role: 'student'),
              _buildUserList(_filter(_owners), role: 'owner'),
            ]),
    );
  }

  Widget _buildUserList(List<UserModel> users, {required String role}) {
    if (users.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.people_outline, size: 72, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text('No ${role}s found', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (_, i) => _buildUserCard(users[i], role: role),
    );
  }

  Widget _buildUserCard(UserModel user, {required String role}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        CircleAvatar(
          radius: 22, backgroundColor: AppColors.primary,
          backgroundImage: user.profileImageUrl.isNotEmpty ? NetworkImage(user.profileImageUrl) : null,
          child: user.profileImageUrl.isEmpty ? Text(user.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          Text(user.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if (role == 'owner' && user.businessName != null) Text(user.businessName!, style: const TextStyle(color: AppColors.primary, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(role, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          if (role == 'owner') ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: user.isApproved ? AppColors.success.withValues(alpha: 0.15) : AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(user.isApproved ? 'Verified' : 'Pending', style: TextStyle(color: user.isApproved ? AppColors.success : AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
      ]),
    );
  }
}

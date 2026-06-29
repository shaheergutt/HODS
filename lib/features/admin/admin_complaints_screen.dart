import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/complaint_model.dart';
import '../../providers/complaint_provider.dart';

class AdminComplaintsScreen extends ConsumerStatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  ConsumerState<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends ConsumerState<AdminComplaintsScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedPriority = 'All';
  String _selectedStatus = 'All';
  String _sortBy = 'newest'; // 'newest', 'oldest', 'priority'

  static const List<String> _categories = [
    'All', 'Electricity', 'Water', 'Internet', 'Mess', 'Security', 'Maintenance', 'Cleanliness', 'Other'
  ];

  static const List<String> _priorities = ['All', 'low', 'medium', 'high', 'urgent'];
  static const List<String> _statuses = [
    'All', 'pending', 'assigned', 'inProgress', 'waitingForStudent', 'resolved', 'closed', 'rejected', 'reopened'
  ];

  String _calculateAvgResolutionTime(List<ComplaintModel> complaints) {
    final resolved = complaints.where((c) => c.resolvedAt != null).toList();
    if (resolved.isEmpty) return 'N/A';
    int totalMinutes = 0;
    for (final c in resolved) {
      totalMinutes += c.resolvedAt!.difference(c.createdAt).inMinutes;
    }
    final avgMinutes = totalMinutes ~/ resolved.length;
    if (avgMinutes < 60) return '$avgMinutes min';
    final avgHours = avgMinutes ~/ 60;
    if (avgHours < 24) return '$avgHours hours';
    final avgDays = avgHours ~/ 24;
    return '$avgDays days';
  }

  List<ComplaintModel> _applyFiltersAndSort(List<ComplaintModel> list) {
    // 1. Filter
    var filtered = list.where((c) {
      final matchesSearch = c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.hostelName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.category.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesCategory = _selectedCategory == 'All' || c.category == _selectedCategory;
      final matchesPriority = _selectedPriority == 'All' || c.priority.name == _selectedPriority;
      final matchesStatus = _selectedStatus == 'All' || c.status.name == _selectedStatus;

      return matchesSearch && matchesCategory && matchesPriority && matchesStatus;
    }).toList();

    // 2. Sort
    if (_sortBy == 'newest') {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_sortBy == 'oldest') {
      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else if (_sortBy == 'priority') {
      filtered.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final complaintsAsync = ref.watch(allComplaintsProvider);

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
              context.go('/admin');
            }
          },
        ),
        title: const Text('Manage Complaints',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: complaintsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
        data: (complaints) {
          final filtered = _applyFiltersAndSort(complaints);
          final total = complaints.length;
          final active = complaints.where((c) => c.status != ComplaintStatus.closed && c.status != ComplaintStatus.rejected).length;
          final resolved = complaints.where((c) => c.status == ComplaintStatus.resolved || c.status == ComplaintStatus.closed).length;
          final highPriority = complaints.where((c) => c.priority == ComplaintPriority.high || c.priority == ComplaintPriority.urgent).length;
          final avgResolution = _calculateAvgResolutionTime(complaints);

          return CustomScrollView(
            slivers: [
              // Statistics Cards Grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.1,
                    ),
                    children: [
                      _buildStatCard('Total', total.toString(), AppColors.textPrimary),
                      _buildStatCard('Active', active.toString(), AppColors.warning),
                      _buildStatCard('Resolved', resolved.toString(), AppColors.success),
                      _buildStatCard('High Priority', highPriority.toString(), AppColors.error),
                      _buildStatCard('Avg Time', avgResolution, AppColors.info),
                    ],
                  ),
                ),
              ),

              // Filter Controls & Search Panel
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search bar
                      TextField(
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search by student, hostel, title...',
                          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                      const SizedBox(height: 12),

                      // Filter chips row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterDropdown('Category', _selectedCategory, _categories, (val) => setState(() => _selectedCategory = val!)),
                            const SizedBox(width: 8),
                            _buildFilterDropdown('Priority', _selectedPriority, _priorities, (val) => setState(() => _selectedPriority = val!)),
                            const SizedBox(width: 8),
                            _buildFilterDropdown('Status', _selectedStatus, _statuses, (val) => setState(() => _selectedStatus = val!)),
                            const SizedBox(width: 8),
                            _buildFilterDropdown('Sort', _sortBy, ['newest', 'oldest', 'priority'], (val) => setState(() => _sortBy = val!)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // List of Complaints
              if (filtered.isEmpty)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No complaints match current filters.', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final complaint = filtered[index];
                        return _buildAdminComplaintCard(context, complaint);
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String currentVal, List<String> options, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentVal,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
          items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt.toUpperCase()))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildAdminComplaintCard(BuildContext context, ComplaintModel complaint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              _categoryIcon(complaint.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(complaint.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Hostel: ${complaint.hostelName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              _statusBadge(complaint.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(complaint.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Student: ${complaint.studentName}', style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
                  Text('Filed on: ${_formatDate(complaint.createdAt)}', style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
                ],
              ),
              Row(
                children: [
                  _priorityBadge(complaint.priority),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primaryLight),
                    onPressed: () => context.push('/admin/complaints/${complaint.id}'),
                  ),
                ],
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: color),
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
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _priorityBadge(ComplaintPriority priority) {
    final map = {
      ComplaintPriority.low: AppColors.success,
      ComplaintPriority.medium: AppColors.info,
      ComplaintPriority.high: AppColors.warning,
      ComplaintPriority.urgent: AppColors.error,
    };
    final color = map[priority]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(priority.priorityLabel.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

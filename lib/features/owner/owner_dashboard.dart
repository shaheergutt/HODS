import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/hostel_model.dart';
import '../../models/room_model.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hostel_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../models/complaint_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/shimmer_loading_widget.dart';
import '../../widgets/common/error_state_widget.dart';

class OwnerDashboard extends ConsumerWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
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
        if (user == null) return const Scaffold(backgroundColor: AppColors.background);
        if (user.approvalStatus != 'approved') return _buildPendingApprovalScreen(context, ref, user);
        return _OwnerDashboardContent(user: user);
      },
    );
  }

  Widget _buildPendingApprovalScreen(BuildContext context, WidgetRef ref, UserModel user) {
    final isRejected = user.approvalStatus == 'rejected';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (isRejected ? AppColors.error : AppColors.warning).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRejected ? Icons.cancel_outlined : Icons.hourglass_top,
                  size: 72,
                  color: isRejected ? AppColors.error : AppColors.warning,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isRejected ? 'Approval Rejected' : 'Approval Pending',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                isRejected
                    ? 'Your hostel owner registration was not approved. Please contact support or verify your credentials.'
                    : 'Your account is under review by our admin team. You\'ll be able to manage your hostels once approved. This usually takes 1-2 business days.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _infoRow(Icons.person, 'Name', user.name),
                    _infoRow(Icons.business, 'Business', user.businessName ?? '-'),
                    _infoRow(Icons.credit_card, 'CNIC', user.cnic ?? '-'),
                    _infoRow(Icons.location_on, 'Hostel Address', user.hostelAddress ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _OwnerDashboardContent extends ConsumerStatefulWidget {
  final UserModel user;
  const _OwnerDashboardContent({required this.user});

  @override
  ConsumerState<_OwnerDashboardContent> createState() => _OwnerDashboardContentState();
}

class _OwnerDashboardContentState extends ConsumerState<_OwnerDashboardContent> {
  String _selectedHostelId = 'all';
  int _activeChartTab = 0; // 0 for Revenue, 1 for Bookings

  Future<void> _deactivateHostel(HostelModel hostel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Deactivate Hostel', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Are you sure you want to deactivate and soft delete "${hostel.name}"? It will no longer be visible to students.', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirestoreService().deleteHostel(hostel.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hostel deactivated successfully'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostelsAsync = ref.watch(ownerHostelsProvider(widget.user.uid));
    final bookingsAsync = ref.watch(ownerBookingsProvider(widget.user.uid));
    final complaintsAsync = ref.watch(ownerComplaintsProvider(widget.user.uid));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: hostelsAsync.when(
        loading: () => SafeArea(child: SingleChildScrollView(child: ShimmerLoadingWidget.dashboardSkeleton())),
        error: (e, _) => ErrorStateWidget(
          message: 'Error loading hostels: $e',
          onRetry: () => ref.invalidate(ownerHostelsProvider(widget.user.uid)),
        ),
        data: (hostels) {
          final activeHostels = hostels.where((h) => h.isActive).toList();

          if (activeHostels.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.home_work_outlined, size: 80, color: AppColors.textHint),
                    const SizedBox(height: 16),
                    const Text('No hostels added yet', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Add your first hostel listing to start receiving student bookings.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/owner/add-hostel'),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Add Your First Hostel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final hostelIds = activeHostels.map((h) => h.id).toList();

          return StreamBuilder<List<RoomModel>>(
            stream: FirestoreService().getOwnerRooms(hostelIds),
            builder: (context, roomsSnap) {
              final rooms = roomsSnap.data ?? [];
              final filteredRooms = _selectedHostelId == 'all'
                  ? rooms
                  : rooms.where((r) => r.hostelId == _selectedHostelId).toList();

              // Vacancy Details Scorecard calculations
              int totalRooms = filteredRooms.length;
              int totalBeds = 0;
              int occupiedBeds = 0;
              for (final r in filteredRooms) {
                totalBeds += r.capacity;
                occupiedBeds += r.occupiedBeds;
              }
              final availableBeds = totalBeds - occupiedBeds;

              final bookingsList = bookingsAsync.value ?? [];
              final filteredBookings = _selectedHostelId == 'all'
                  ? bookingsList
                  : bookingsList.where((b) => b.hostelId == _selectedHostelId).toList();

              int pendingRequests = filteredBookings.where((b) => b.status == BookingStatus.pending).length;
              int confirmedBookings = filteredBookings.where((b) => b.status == BookingStatus.confirmed).length;
              double revenueEstimate = filteredBookings
                  .where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.completed)
                  .fold(0.0, (sum, b) => sum + b.totalAmount);

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: AppColors.background,
                    floating: true,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Owner Dashboard', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
                        Text('Welcome, ${widget.user.name}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.person_outline, color: AppColors.textPrimary),
                        onPressed: () => context.push('/owner/profile'),
                      ),
                    ],
                  ),
                  // Dropdown Filter
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Property Filter:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedHostelId,
                                    dropdownColor: AppColors.surface,
                                    isExpanded: true,
                                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                    items: [
                                      const DropdownMenuItem(value: 'all', child: Text('All Hostels')),
                                      ...activeHostels.map((h) => DropdownMenuItem(value: h.id, child: Text(h.name))),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedHostelId = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Scorecard Grid
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dashboard Statistics', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _scoreCard('Total Rooms', totalRooms.toString(), Icons.meeting_room_outlined, AppColors.info),
                              const SizedBox(width: 10),
                              _scoreCard('Occupied Beds', occupiedBeds.toString(), Icons.check_circle_outline, AppColors.success),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _scoreCard('Available Beds', availableBeds.toString(), Icons.bed_outlined, AppColors.warning),
                              const SizedBox(width: 10),
                              _scoreCard('Pending Requests', pendingRequests.toString(), Icons.hourglass_top, AppColors.primaryLight),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _scoreCard('Confirmed Bookings', confirmedBookings.toString(), Icons.done_all, AppColors.success),
                              const SizedBox(width: 10),
                              _scoreCard('Revenue Estimate', 'PKR ${revenueEstimate.toInt()}', Icons.currency_rupee, AppColors.secondary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // fl_chart Analytics
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: bookingsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error loading chart data: $e', style: const TextStyle(color: AppColors.error)),
                        data: (bookings) {
                          return _buildAnalyticsChart(bookings);
                        },
                      ),
                    ),
                  ),
                  // Complaints Summary Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: complaintsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error loading complaints: $e', style: const TextStyle(color: AppColors.error)),
                        data: (complaints) => _buildComplaintsSummary(complaints),
                      ),
                    ),
                  ),
                  // Quick Actions Grid
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quick Actions', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _buildQuickActionsGrid(context),
                        ],
                      ),
                    ),
                  ),
                  // My Hostels List Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('My Listings', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () => context.push('/owner/add-hostel'),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Hostel', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // My Hostels List Content
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final hostel = activeHostels[i];
                          final hostelRooms = rooms.where((r) => r.hostelId == hostel.id).toList();
                          int hTotalBeds = 0;
                          int hOccupied = 0;
                          for (final r in hostelRooms) {
                            hTotalBeds += r.capacity;
                            hOccupied += r.occupiedBeds;
                          }
                          return _buildOwnerHostelCard(context, hostel, hTotalBeds, hOccupied);
                        },
                        childCount: activeHostels.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _scoreCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsChart(List<BookingModel> bookings) {
    // Aggegating revenue and count per month
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - 5 + i);
      return d.month;
    });

    final Map<int, double> monthlyRevenue = {};
    final Map<int, int> monthlyBookingsCount = {};

    // Seed empty months with a small baseline so graph isn't empty, then add real data
    for (final m in months) {
      monthlyRevenue[m] = 0.0;
      monthlyBookingsCount[m] = 0;
    }

    for (final b in bookings) {
      if (b.status == BookingStatus.confirmed || b.status == BookingStatus.completed) {
        final bMonth = b.createdAt.month;
        if (monthlyRevenue.containsKey(bMonth)) {
          monthlyRevenue[bMonth] = monthlyRevenue[bMonth]! + b.totalAmount;
          monthlyBookingsCount[bMonth] = monthlyBookingsCount[bMonth]! + 1;
        }
      }
    }

    final List<FlSpot> revenueSpots = [];
    final List<BarChartGroupData> bookingsBarGroups = [];

    for (int i = 0; i < months.length; i++) {
      final monthVal = months[i];
      final rev = monthlyRevenue[monthVal] ?? 0.0;
      final count = monthlyBookingsCount[monthVal] ?? 0;

      revenueSpots.add(FlSpot(i.toDouble(), rev));
      bookingsBarGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: AppColors.primary,
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Performance Analytics', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _activeChartTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _activeChartTab == 0 ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Revenue', style: TextStyle(color: _activeChartTab == 0 ? Colors.white : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _activeChartTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _activeChartTab == 1 ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Bookings', style: TextStyle(color: _activeChartTab == 1 ? Colors.white : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: _activeChartTab == 0
                ? LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 45,
                            getTitlesWidget: (v, meta) {
                              if (v >= 1000) return Text('${(v / 1000).toStringAsFixed(0)}K', style: const TextStyle(color: AppColors.textSecondary, fontSize: 9));
                              return Text(v.toStringAsFixed(0), style: const TextStyle(color: AppColors.textSecondary, fontSize: 9));
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, meta) {
                              final index = v.toInt();
                              if (index >= 0 && index < months.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(monthNames[months[index]], style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: revenueSpots,
                          isCurved: true,
                          color: AppColors.secondary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.secondary.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
                  )
                : BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: 1.0,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, meta) {
                              final index = v.toInt();
                              if (index >= 0 && index < months.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(monthNames[months[index]], style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: bookingsBarGroups,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintsSummary(List<ComplaintModel> complaints) {
    final total = complaints.length;
    final pending = complaints.where((c) => c.status == ComplaintStatus.pending).length;
    final inProgress = complaints.where((c) => c.status == ComplaintStatus.inProgress).length;
    final resolved = complaints.where((c) => c.status == ComplaintStatus.resolved).length;
    final reopened = complaints.where((c) => c.status == ComplaintStatus.reopened).length;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Complaints Overview', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => context.push('/owner/complaints'),
                child: const Text('Manage all', style: TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _summaryCol('Total', total.toString(), AppColors.textPrimary),
              _summaryDivider(),
              _summaryCol('Pending', pending.toString(), AppColors.info),
              _summaryDivider(),
              _summaryCol('In Progress', inProgress.toString(), AppColors.warning),
              _summaryDivider(),
              _summaryCol('Resolved', resolved.toString(), AppColors.success),
              _summaryDivider(),
              _summaryCol('Reopened', reopened.toString(), Colors.deepOrange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCol(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(width: 1, height: 24, color: AppColors.border);
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final actions = [
      {'icon': Icons.add_home_outlined, 'label': 'Add Hostel', 'route': '/owner/add-hostel'},
      {'icon': Icons.book_online_outlined, 'label': 'Bookings', 'route': '/owner/bookings'},
      {'icon': Icons.qr_code_scanner_outlined, 'label': 'QR Check-in', 'route': '/owner/qr-scanner'},
      {'icon': Icons.analytics_outlined, 'label': 'Vacancy AI', 'route': '/owner/forecast'},
      {'icon': Icons.feedback_outlined, 'label': 'Complaints', 'route': '/owner/complaints'},
      {'icon': Icons.account_circle_outlined, 'label': 'Profile', 'route': '/owner/profile'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final a = actions[index];
        return GestureDetector(
          onTap: () => context.push(a['route'] as String),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a['icon'] as IconData, color: AppColors.primaryLight, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  a['label'] as String,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOwnerHostelCard(BuildContext context, HostelModel hostel, int totalBeds, int occupiedBeds) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image/Icon thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: hostel.imageUrls.isNotEmpty
                    ? Image.network(hostel.imageUrls.first, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildIconThumbnail())
                    : _buildIconThumbnail(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hostel.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 13),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${hostel.location}, ${hostel.city}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                          child: Text(hostel.genderPolicy, style: const TextStyle(color: AppColors.info, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.secondary, size: 14),
                      const SizedBox(width: 2),
                      Text(hostel.rating.toStringAsFixed(1), style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('PKR ${hostel.pricePerMonth.toStringAsFixed(0)}/mo', style: const TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Vacancy: ${totalBeds - occupiedBeds} / $totalBeds beds free',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                    onPressed: () => _deactivateHostel(hostel),
                    tooltip: 'Deactivate Hostel',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/owner/edit-hostel/${hostel.id}'),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/owner/hostel/${hostel.id}/rooms'),
                    icon: const Icon(Icons.bed, size: 14, color: Colors.white),
                    label: const Text('Rooms', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconThumbnail() {
    return Container(
      width: 64,
      height: 64,
      color: AppColors.primary.withValues(alpha: 0.1),
      child: const Icon(Icons.apartment, color: AppColors.primary, size: 28),
    );
  }
}

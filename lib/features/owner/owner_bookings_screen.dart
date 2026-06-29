import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/booking_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/firestore_service.dart';

class OwnerBookingsScreen extends ConsumerStatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  ConsumerState<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends ConsumerState<OwnerBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showStudentProfile(BuildContext context, BookingModel booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return FutureBuilder<UserModel?>(
            future: FirestoreService().getUser(booking.studentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data == null) {
                return const Center(
                  child: Text('Could not load student profile', style: TextStyle(color: AppColors.error)),
                );
              }

              final student = snapshot.data!;
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(student.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              if (student.phone.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(student.phone, style: const TextStyle(color: AppColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 16),
                    // Academic details
                    const Text('Education', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _profileInfoCard(Icons.school_outlined, 'University', student.university ?? 'Not specified'),
                    const SizedBox(height: 20),
                    // Living Preferences
                    const Text('Living Preferences', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _preferenceTag('Cleanliness: ${student.cleanlinessPref}'),
                        _preferenceTag('Noise: ${student.noisePref}'),
                        _preferenceTag('Sharing: ${student.sharingPref}'),
                        _preferenceTag('Diet: ${student.dietPref}'),
                        _preferenceTag('Transport: ${student.transportPref}'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Search preferences
                    const Text('Hostel Preferences', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _profileInfoCard(Icons.location_city_outlined, 'Preferred City', student.preferredCity ?? 'Any'),
                    const SizedBox(height: 8),
                    _profileInfoCard(Icons.currency_rupee, 'Budget Range', 'Rs. ${student.budgetMin} - Rs. ${student.budgetMax}'),
                    const SizedBox(height: 16),
                    if (student.preferredFacilities.isNotEmpty) ...[
                      const Text('Preferred Facilities', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: student.preferredFacilities.map((f) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(f, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11)),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _profileInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preferenceTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(backgroundColor: AppColors.background, body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) return const Scaffold(backgroundColor: AppColors.background);
        final bookingsAsync = ref.watch(ownerBookingsProvider(user.uid));

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            title: const Text('Manage Bookings', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/owner');
                }
              },
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryLight,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Confirmed'),
                Tab(text: 'Cancelled'),
                Tab(text: 'Occupants'),
              ],
            ),
          ),
          body: bookingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
            data: (bookings) {
              final now = DateTime.now();

              // Tab 1: Pending
              final pendingBookings = bookings.where((b) => b.status == BookingStatus.pending).toList();

              // Tab 2: Confirmed (Upcoming/Standard Confirmed)
              final confirmedBookings = bookings.where((b) {
                if (b.status != BookingStatus.confirmed) return false;
                // Exclude current occupants
                final isCurrentOccupant = (now.isAfter(b.checkInDate) || DateUtils.isSameDay(now, b.checkInDate)) && now.isBefore(b.checkOutDate);
                return !isCurrentOccupant;
              }).toList();

              // Tab 3: Cancelled/Rejected
              final cancelledBookings = bookings.where((b) => b.status == BookingStatus.cancelled).toList();

              // Tab 4: Current Occupants (Confirmed bookings currently in house)
              final currentOccupants = bookings.where((b) {
                if (b.status != BookingStatus.confirmed) return false;
                final isCurrentOccupant = (now.isAfter(b.checkInDate) || DateUtils.isSameDay(now, b.checkInDate)) && now.isBefore(b.checkOutDate);
                return isCurrentOccupant;
              }).toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildBookingsList(pendingBookings),
                  _buildBookingsList(confirmedBookings),
                  _buildBookingsList(cancelledBookings),
                  _buildBookingsList(currentOccupants),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBookingsList(List<BookingModel> bookings) {
    if (bookings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppColors.textHint),
            SizedBox(height: 12),
            Text('No bookings in this category', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, i) => _buildBookingCard(context, bookings[i]),
    );
  }

  Widget _buildBookingCard(BuildContext context, BookingModel b) {
    final isPending = b.status == BookingStatus.pending;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _showStudentProfile(context, b),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Text(
                      b.studentName.isNotEmpty ? b.studentName[0].toUpperCase() : 'S',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.studentName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(b.hostelName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          'PKR ${b.totalAmount.toInt()} (${b.bookingType == BookingType.monthly ? "${b.durationMonths} mo" : "${b.durationDays} days"})',
                          style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statusBadge(b.status),
                      const SizedBox(height: 8),
                      const Text(
                        'View Profile',
                        style: TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _dateInfo('Check-in', b.checkInDate)),
                Container(width: 1, height: 32, color: AppColors.border),
                Expanded(child: _dateInfo('Check-out', b.checkOutDate)),
              ],
            ),
          ),
          if (isPending) ...[
            const Divider(color: AppColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateStatus(b, BookingStatus.cancelled),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(b, BookingStatus.confirmed),
                      icon: const Icon(Icons.check, size: 16, color: Colors.white),
                      label: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateStatus(BookingModel b, BookingStatus status) async {
    try {
      await FirestoreService().updateBookingStatus(b.id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking ${status.name}'),
            backgroundColor: status == BookingStatus.confirmed ? AppColors.success : AppColors.error,
          ),
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

  Widget _statusBadge(BookingStatus s) {
    final colors = {
      BookingStatus.pending: AppColors.warning,
      BookingStatus.confirmed: AppColors.success,
      BookingStatus.cancelled: AppColors.error,
      BookingStatus.completed: AppColors.info
    };
    final color = colors[s] ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        s.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _dateInfo(String label, DateTime date) => Column(
    children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      const SizedBox(height: 2),
      Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
    ],
  );
}

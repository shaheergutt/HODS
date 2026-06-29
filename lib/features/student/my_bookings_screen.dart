import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/firestore_service.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed: return AppColors.success;
      case BookingStatus.pending: return AppColors.warning;
      case BookingStatus.cancelled: return AppColors.error;
      case BookingStatus.completed: return AppColors.info;
    }
  }

  IconData _statusIcon(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed: return Icons.check_circle;
      case BookingStatus.pending: return Icons.hourglass_top;
      case BookingStatus.cancelled: return Icons.cancel;
      case BookingStatus.completed: return Icons.done_all;
    }
  }

  void _showQrDialog(BuildContext context, BookingModel b) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        // Use Dialog (NOT AlertDialog) to avoid the internal IntrinsicWidth
        // wrapper that causes "size: MISSING" when QrImageView is inside a
        // Column(mainAxisSize: MainAxisSize.min).
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Text(
                b.hostelName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${b.id}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),

              // QR code — explicit SizedBox prevents intrinsic sizing failure
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: QrImageView(
                    data: b.qrToken ?? b.id,
                    version: QrVersions.auto,
                    size: 200.0,
                    gapless: false,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Show this QR code to the hostel owner at check-in.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _cancelBooking(BuildContext context, WidgetRef ref, BookingModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Booking', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to cancel this booking? This action will release your reserved bed.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, Keep it', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirestoreService().updateBookingStatus(booking.id, BookingStatus.cancelled);
        ref.invalidate(studentBookingsProvider(booking.studentId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled successfully'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel booking: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(backgroundColor: AppColors.background, body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) return const Scaffold(backgroundColor: AppColors.background);
        final bookingsAsync = ref.watch(studentBookingsProvider(user.uid));
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            title: const Text('My Bookings', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/student');
                }
              },
            ),
          ),
          body: bookingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (bookings) {
              if (bookings.isEmpty) {
                return const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.book_online, size: 72, color: AppColors.textSecondary),
                    SizedBox(height: 16),
                    Text('No Bookings Yet', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Your bookings will appear here', style: TextStyle(color: AppColors.textSecondary)),
                  ]),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: bookings.length,
                itemBuilder: (ctx, i) {
                  final b = bookings[i];
                  final color = _statusColor(b.status);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.home_work_rounded, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(b.hostelName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text('Room ${b.roomNumber} (${b.roomType.toUpperCase()}) - ${b.bedsBooked} Bed(s)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text('PKR ${b.totalAmount.toInt()} total', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(_statusIcon(b.status), size: 12, color: color),
                              const SizedBox(width: 4),
                              Text(b.status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ]),
                      ),
                      const Divider(color: AppColors.border, height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Expanded(child: _dateInfo('Check-in', b.checkInDate)),
                          Container(width: 1, height: 32, color: AppColors.border),
                          Expanded(child: _dateInfo('Check-out', b.checkOutDate)),
                          Container(width: 1, height: 32, color: AppColors.border),
                          Expanded(child: _dateInfo('Booked On', b.createdAt)),
                        ]),
                      ),
                      if (b.status == BookingStatus.pending || b.status == BookingStatus.confirmed) ...[
                        const Divider(color: AppColors.border, height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showQrDialog(context, b),
                                icon: const Icon(Icons.qr_code_2, color: AppColors.primaryLight, size: 18),
                                label: const Text('Show QR', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              TextButton.icon(
                                onPressed: () => _cancelBooking(context, ref, b),
                                icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),
                                label: const Text('Cancel Booking', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ]),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _dateInfo(String label, DateTime date) => Column(children: [
    Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
  ]);
}

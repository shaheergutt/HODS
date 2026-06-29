import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import '../../models/booking_model.dart';
import '../../services/notification_service.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  late final MobileScannerController _scannerController;
  final _manualIdController = TextEditingController();
  bool _isProcessing = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualIdController.dispose();
    super.dispose();
  }

  /// Safely start the scanner (no-op if already running).
  void _resumeScanner() {
    if (mounted && !_isProcessing) {
      _scannerController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Verify QR Check-In',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
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
        actions: [
          // Torch toggle
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? AppColors.secondary : AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() => _torchOn = !_torchOn);
              _scannerController.toggleTorch();
            },
          ),
          // Camera switch
          IconButton(
            icon: const Icon(Icons.flip_camera_android_outlined, color: AppColors.primaryLight),
            onPressed: () => _scannerController.switchCamera(const ToggleLensType()),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Scanner box ─────────────────────────────────────────
            Container(
              height: MediaQuery.of(context).size.height * 0.45,
              margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        if (_isProcessing) return;
                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final code = barcodes.first.rawValue;
                          if (code != null && code.isNotEmpty) {
                            _processBookingId(code.trim());
                          }
                        }
                      },
                    ),

                    // Corner-frame overlay (QR viewfinder)
                    Center(
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          children: [
                            // Top-left corner
                            Positioned(
                              top: 0, left: 0,
                              child: _corner(top: true, left: true),
                            ),
                            // Top-right corner
                            Positioned(
                              top: 0, right: 0,
                              child: _corner(top: true, left: false),
                            ),
                            // Bottom-left corner
                            Positioned(
                              bottom: 0, left: 0,
                              child: _corner(top: false, left: true),
                            ),
                            // Bottom-right corner
                            Positioned(
                              bottom: 0, right: 0,
                              child: _corner(top: false, left: false),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Processing overlay
                    if (_isProcessing)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: AppColors.primaryLight),
                              SizedBox(height: 12),
                              Text('Verifying booking…',
                                  style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // -- Hint text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                "Align the student's check-in QR code within the frame to verify instantly.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),

            const SizedBox(height: 24),

            // ── Divider ───────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      'OR ENTER BOOKING ID MANUALLY',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Manual ID entry ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: TextField(
                controller: _manualIdController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter Booking ID or QR Token…',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: const Icon(Icons.tag, color: AppColors.primary, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_outlined, color: AppColors.primaryLight),
                    onPressed: () {
                      final text = _manualIdController.text.trim();
                      if (text.isNotEmpty) _processBookingId(text);
                    },
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) _processBookingId(val.trim());
                },
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Corner bracket widget for the QR finder overlay.
  Widget _corner({required bool top, required bool left}) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: AppColors.secondary, width: 3) : BorderSide.none,
          bottom: !top ? const BorderSide(color: AppColors.secondary, width: 3) : BorderSide.none,
          left: left ? const BorderSide(color: AppColors.secondary, width: 3) : BorderSide.none,
          right: !left ? const BorderSide(color: AppColors.secondary, width: 3) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(4) : Radius.zero,
          topRight: top && !left ? const Radius.circular(4) : Radius.zero,
          bottomLeft: !top && left ? const Radius.circular(4) : Radius.zero,
          bottomRight: !top && !left ? const Radius.circular(4) : Radius.zero,
        ),
      ),
    );
  }

  // ── Core Logic ────────────────────────────────────────────────────

  Future<void> _processBookingId(String scannedValue) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await _scannerController.stop();

    try {
      BookingModel? booking;

      // ── Step 1: Query by qrToken field ──────────────────────────────────
      // QR codes store the qrToken UUID value, NOT the Firestore document ID.
      final tokenQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('qrToken', isEqualTo: scannedValue)
          .limit(1)
          .get();

      if (tokenQuery.docs.isNotEmpty) {
        final doc = tokenQuery.docs.first;
        booking = BookingModel.fromMap(doc.data(), doc.id);
      }

      // ── Step 2: Fallback — treat value as direct document ID ─────────────
      // Handles old bookings created before qrToken was introduced, or
      // cases where b.qrToken was null so the QR encodes b.id directly.
      if (booking == null) {
        final docSnap = await FirebaseFirestore.instance
            .collection('bookings')
            .doc(scannedValue)
            .get();

        if (docSnap.exists && docSnap.data() != null) {
          booking = BookingModel.fromMap(docSnap.data()!, docSnap.id);
        }
      }

      if (!mounted) return;

      if (booking == null) {
        _showErrorDialog(
          'Booking Not Found',
          'No booking matches this QR code.\n\nScanned value:\n$scannedValue',
        );
        return;
      }

      _showBookingDetailsSheet(booking);
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Verification Error', 'Failed to retrieve booking:\n$e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }


  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resumeScanner();
            },
            child: const Text('Try Again', style: TextStyle(color: AppColors.primaryLight)),
          ),
        ],
      ),
    );
  }

  void _showBookingDetailsSheet(BookingModel booking) {
    final bool isCompleted = booking.status == BookingStatus.completed;
    final bool isCancelled = booking.status == BookingStatus.cancelled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user, color: AppColors.success, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Booking Found',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // Booking details
            _detailRow('Student', booking.studentName),
            _detailRow('Hostel', booking.hostelName),
            _detailRow('Room', 'Room ${booking.roomNumber}'),
            _detailRow(
              'Stay Type',
              booking.bookingType == BookingType.daily
                  ? 'Daily (Tourist)'
                  : 'Monthly',
              valueColor: booking.bookingType == BookingType.daily
                  ? AppColors.secondary
                  : AppColors.primaryLight,
            ),
            _detailRow(
              'Duration',
              booking.bookingType == BookingType.daily
                  ? '${booking.durationDays} day(s)'
                  : '${booking.durationMonths} month(s)',
            ),
            _detailRow(
              'Check-in',
              '${booking.checkInDate.day}/${booking.checkInDate.month}/${booking.checkInDate.year}',
            ),
            _detailRow(
              'Amount',
              'PKR ${booking.totalAmount.toInt()}',
              valueColor: AppColors.primary,
            ),
            _detailRow(
              'Status',
              booking.statusLabel,
              valueColor: _statusColor(booking.status),
            ),
            const SizedBox(height: 20),

            // Action button
            if (isCancelled)
              _statusBanner(
                Icons.cancel_outlined,
                'This booking has been cancelled',
                AppColors.error,
              )
            else if (isCompleted)
              _statusBanner(
                Icons.done_all,
                'This booking is already completed',
                AppColors.info,
              )
            else if (booking.status == BookingStatus.confirmed)
              _statusBanner(
                Icons.check_circle_outline,
                'Already Checked-In',
                AppColors.success,
              )
            else
              // pending → allow confirm check-in
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _confirmCheckIn(booking, ctx),
                  icon: const Icon(Icons.how_to_reg_outlined, color: Colors.white),
                  label: const Text(
                    'Confirm Check-In',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _resumeScanner();
                },
                icon: const Icon(Icons.qr_code_scanner, color: AppColors.textSecondary, size: 18),
                label: const Text(
                  'Scan Another Code',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(IconData icon, String message, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return AppColors.success;
      case BookingStatus.pending:
        return AppColors.warning;
      case BookingStatus.cancelled:
        return AppColors.error;
      case BookingStatus.completed:
        return AppColors.info;
    }
  }

  Future<void> _confirmCheckIn(BookingModel booking, BuildContext sheetCtx) async {
    Navigator.pop(sheetCtx); // close bottom sheet first
    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(booking.id)
          .update({'status': BookingStatus.confirmed.name});

      // Notify student
      await NotificationService().sendNotification(
        title: 'Check-In Confirmed! 🎉',
        body:
            'Your check-in at "${booking.hostelName}" was verified by the owner.',
        userId: booking.studentId,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Check-In Verified!',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${booking.studentName} has been checked in successfully.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resumeScanner();
                  },
                  child: const Text(
                    'Scan Next',
                    style: TextStyle(
                        color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Check-In Failed', 'Could not confirm check-in:\n$e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../models/complaint_model.dart';
import '../../models/hostel_model.dart';
import '../../models/booking_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hostel_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/complaint_provider.dart';

class ComplaintFormScreen extends ConsumerStatefulWidget {
  const ComplaintFormScreen({super.key});

  @override
  ConsumerState<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends ConsumerState<ComplaintFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  static const List<String> _categories = [
    'Electricity', 'Water', 'Internet', 'Mess',
    'Security', 'Maintenance', 'Cleanliness', 'Other',
  ];

  String _selectedCategory = 'Electricity';
  ComplaintPriority _selectedPriority = ComplaintPriority.medium;
  HostelModel? _selectedHostel;
  BookingModel? _selectedBooking;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// Returns the list of hostels the student has an active booking for.
  List<HostelModel> _resolveStudentHostels(
    List<BookingModel> bookings,
    List<HostelModel> allHostels,
  ) {
    final activeHostelIds = bookings
        .where((b) =>
            b.status == BookingStatus.confirmed ||
            b.status == BookingStatus.completed)
        .map((b) => b.hostelId)
        .toSet();

    final matched =
        allHostels.where((h) => activeHostelIds.contains(h.id)).toList();

    // Fallback: show all approved hostels if student has no confirmed booking
    if (matched.isEmpty) {
      return allHostels.where((h) => h.isApproved).toList();
    }
    return matched;
  }

  Future<void> _submit(UserModel student, HostelModel hostel) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showError('You are not logged in. Please log in and try again.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final complaint = ComplaintModel(
        id: '', // assigned by service
        studentId: uid,
        studentName: student.name,
        hostelId: hostel.id,
        hostelName: hostel.name,
        hostelOwnerId: hostel.ownerId,
        bookingId: _selectedBooking?.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _selectedCategory,
        priority: _selectedPriority,
        status: ComplaintStatus.pending,
        rating: 0,
        ownerReply: '',
        createdAt: now,
        updatedAt: now,
      );

      final complaintService = ref.read(complaintServiceProvider);
      final complaintId = await complaintService.createComplaint(complaint);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Complaint submitted successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(complaintId);
    } on FirebaseException catch (e) {
      _showError(_friendlyFirebaseError(e.code));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyFirebaseError(String code) {
    switch (code) {
      case 'permission-denied':
        return 'You don\'t have permission to perform this action.';
      case 'not-found':
        return 'The requested resource was not found.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Please check your internet connection and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

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
              final user = ref.read(currentUserProvider).value;
              context.go(user?.role == UserRole.owner ? '/owner' : '/student');
            }
          },
        ),
        title: const Text(
          'File a Complaint',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading profile: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text(
                'Please log in to file a complaint.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return _buildForm(user);
        },
      ),
    );
  }

  Widget _buildForm(UserModel student) {
    final bookingsAsync = ref.watch(studentBookingsProvider(student.uid));
    final hostelsAsync = ref.watch(allHostelsProvider);

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error loading bookings: $e',
            style: const TextStyle(color: AppColors.error)),
      ),
      data: (bookings) => hostelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading hostels: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
        data: (allHostels) {
          final studentHostels =
              _resolveStudentHostels(bookings, allHostels);
          _selectedHostel ??=
              studentHostels.isNotEmpty ? studentHostels.first : null;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header card ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.report_problem_outlined,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Report an Issue',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              SizedBox(height: 2),
                              Text(
                                'Your complaint will be sent to the hostel owner.',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Booking selector (Phase 3) ────────────────
                  if (bookings.isNotEmpty) ...[
                    _buildSectionLabel('Select Booking (Optional)', Icons.book_online_outlined),
                    const SizedBox(height: 8),
                    _buildDropdownContainer(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<BookingModel?>(
                          value: _selectedBooking,
                          hint: const Text('Select a Booking', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          isExpanded: true,
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          items: [
                            const DropdownMenuItem<BookingModel?>(
                              value: null,
                              child: Text('No Specific Booking (General Issue)'),
                            ),
                            ...bookings.map((b) => DropdownMenuItem<BookingModel?>(
                                  value: b,
                                  child: Text('Room ${b.roomId} (${b.hostelName})'),
                                )),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedBooking = val;
                              if (val != null) {
                                final matched = allHostels.firstWhere((h) => h.id == val.hostelId);
                                _selectedHostel = matched;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Hostel selector ───────────────────────────
                  _buildSectionLabel('Select Hostel', Icons.apartment_outlined),
                  const SizedBox(height: 8),
                  if (studentHostels.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.error),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No hostels found. You need a confirmed booking to file a complaint.',
                              style: TextStyle(
                                  color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildDropdownContainer(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<HostelModel>(
                          value: _selectedHostel,
                          isExpanded: true,
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          items: studentHostels.map((h) {
                            return DropdownMenuItem(
                                value: h, child: Text(h.name));
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedHostel = val),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // ── Category ──────────────────────────────────
                  _buildSectionLabel('Category', Icons.category_outlined),
                  const SizedBox(height: 8),
                  _buildDropdownContainer(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        items: _categories.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedCategory = val!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Priority ──────────────────────────────────
                  _buildSectionLabel('Priority', Icons.flag_outlined),
                  const SizedBox(height: 8),
                  Row(
                    children: ComplaintPriority.values.map((p) {
                      final isSelected = _selectedPriority == p;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedPriority = p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _priorityColor(p)
                                      .withValues(alpha: 0.2)
                                  : AppColors.inputFill,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? _priorityColor(p)
                                    : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(_priorityIcon(p),
                                    color: isSelected
                                        ? _priorityColor(p)
                                        : AppColors.textSecondary,
                                    size: 18),
                                const SizedBox(height: 4),
                                Text(
                                  p.name[0].toUpperCase() +
                                      p.name.substring(1),
                                  style: TextStyle(
                                    color: isSelected
                                        ? _priorityColor(p)
                                        : AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Title ─────────────────────────────────────
                  _buildSectionLabel('Title', Icons.title),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: _inputDecoration('e.g. No electricity in room 202'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter a title.';
                      }
                      if (v.trim().length < 5) {
                        return 'Title must be at least 5 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Description ───────────────────────────────
                  _buildSectionLabel('Description', Icons.description_outlined),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    maxLines: 5,
                    decoration: _inputDecoration(
                        'Describe the issue in detail. Include when it started, how it affects you, etc.'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please describe the issue.';
                      }
                      if (v.trim().length < 20) {
                        return 'Description must be at least 20 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // ── Submit button ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: (studentHostels.isEmpty || _isSubmitting)
                          ? null
                          : () => _submit(student, _selectedHostel!),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Submit Complaint',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryLight),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: AppColors.textHint, fontSize: 13),
      filled: true,
      fillColor: AppColors.inputFill,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  Color _priorityColor(ComplaintPriority p) {
    switch (p) {
      case ComplaintPriority.low:
        return AppColors.success;
      case ComplaintPriority.medium:
        return AppColors.info;
      case ComplaintPriority.high:
        return AppColors.warning;
      case ComplaintPriority.urgent:
        return AppColors.error;
    }
  }

  IconData _priorityIcon(ComplaintPriority p) {
    switch (p) {
      case ComplaintPriority.low:
        return Icons.arrow_downward;
      case ComplaintPriority.medium:
        return Icons.remove;
      case ComplaintPriority.high:
        return Icons.arrow_upward;
      case ComplaintPriority.urgent:
        return Icons.priority_high;
    }
  }
}

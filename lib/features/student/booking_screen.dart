import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/hostel_model.dart';
import '../../models/room_model.dart';
import '../../models/booking_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final String hostelId;
  const BookingScreen({super.key, required this.hostelId});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  HostelModel? _hostel;
  RoomModel? _selectedRoom;
  bool _loading = true;
  bool _submitting = false;
  bool _accessDenied = false;

  BookingType _bookingType = BookingType.monthly;
  DateTime? _checkIn;
  DateTimeRange? _stayRange;
  int _months = 1;
  int _bedsBooked = 1;

  @override
  void initState() {
    super.initState();
    // Check role FIRST before doing any data loading.
    // This prevents owners/admins from ever triggering hostel fetching.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).value;
      if (user == null || user.role != UserRole.student) {
        if (mounted) {
          setState(() { _accessDenied = true; _loading = false; });
        }
      } else {
        _loadHostel();
      }
    });
  }

  Future<void> _loadHostel() async {
    try {
      final h = await FirestoreService().getHostel(widget.hostelId);
      if (mounted) setState(() { _hostel = h; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  double get _totalAmount {
    if (_selectedRoom == null) return 0.0;
    final days = _stayRange?.duration.inDays ?? 0;
    return _bookingType == BookingType.monthly
        ? _selectedRoom!.price * _bedsBooked * _months
        : (_selectedRoom!.price / 30.0) * _bedsBooked * days;
  }

  bool get _canBook {
    if (_selectedRoom == null) return false;
    return _bookingType == BookingType.monthly ? _checkIn != null : _stayRange != null;
  }

  Future<void> _book() async {
    if (_hostel == null || _selectedRoom == null || _checkIn == null) return;
    if (_bookingType == BookingType.daily && _stayRange == null) return;
    if (_selectedRoom!.availableBeds < _bedsBooked) {
      _showSnack('Not enough available beds in this room!', AppColors.error);
      return;
    }

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    if (user.role != UserRole.student) {
      _showSnack('Only students can book rooms!', AppColors.error);
      return;
    }

    setState(() => _submitting = true);

    final checkout = _bookingType == BookingType.monthly
        ? DateTime(_checkIn!.year, _checkIn!.month + _months, _checkIn!.day)
        : _stayRange!.end;

    final days = _stayRange?.duration.inDays ?? 0;

    final booking = BookingModel(
      id: '',
      studentId: user.uid,
      studentName: user.name,
      hostelId: _hostel!.id,
      hostelName: _hostel!.name,
      ownerId: _hostel!.ownerId,
      roomId: _selectedRoom!.roomId,
      roomNumber: _selectedRoom!.roomNumber,
      roomType: _selectedRoom!.roomType,
      bedsBooked: _bedsBooked,
      checkInDate: _checkIn!,
      checkOutDate: checkout,
      totalAmount: _totalAmount,
      status: BookingStatus.pending,
      durationMonths: _bookingType == BookingType.monthly ? _months : 0,
      durationDays: _bookingType == BookingType.daily ? days : 0,
      bookingType: _bookingType,
      createdAt: DateTime.now(),
      specialRequests: '',
    );

    try {
      await FirestoreService().createBooking(booking);
      if (mounted) {
        _showSnack('Booking request submitted!', AppColors.success);
        context.go('/student/bookings');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fast-path: access denied set during initState before any data loads
    if (_accessDenied) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Access Denied',
              style: TextStyle(color: AppColors.textPrimary)),
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
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.no_accounts_outlined, size: 80, color: AppColors.error),
                SizedBox(height: 16),
                Text('Students Only',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  'Booking rooms is only available for students.\nHostel owners and admins cannot make bookings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Also watch live auth state so if auth changes we respond immediately
    final user = ref.watch(currentUserProvider).value;
    if (user != null && user.role != UserRole.student) {
      // Role changed while screen was open (shouldn't normally happen, safety net)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }


    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hostel == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
        body: const Center(
          child: Text('Hostel not found.', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final h = _hostel!;

    return Scaffold(
      backgroundColor: AppColors.background,
      // Standard AppBar — no SliverAppBar, so nothing scrolls behind it.
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/student');
            }
          },
        ),
            title: const Text(
              'Book Room',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hostel Header Card ─────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BOOKING REQUEST',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        h.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white54, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${h.location}, ${h.city}',
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              h.genderPolicy,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Step 1: Room Selection
                _stepCard(
                  step: 1,
                  title: 'Select Room',
                  subtitle: 'Choose a room with available beds',
                  icon: Icons.meeting_room_outlined,
                  content: _buildRoomSelector(h),
                ),

                // Step 2: Beds & Dates
                if (_selectedRoom != null) ...[
                  const SizedBox(height: 16),
                  _stepCard(
                    step: 2,
                    title: 'Beds & Stay Duration',
                    subtitle: 'How many beds and for how long?',
                    icon: Icons.bed_outlined,
                    content: _buildBedsAndDates(),
                  ),
                ],

                // Step 3: Summary
                if (_selectedRoom != null && _canBook) ...[
                  const SizedBox(height: 16),
                  _buildSummaryCard(),
                ],

                const SizedBox(height: 100),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Step card wrapper ──────────────────────────────────────────────
  Widget _stepCard({
    required int step,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$step',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(icon, color: AppColors.primary, size: 18),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: content,
          ),
        ],
      ),
    );
  }

  // ── Room selector ──────────────────────────────────────────────────
  Widget _buildRoomSelector(HostelModel h) {
    return StreamBuilder<List<RoomModel>>(
      stream: FirestoreService().getHostelRooms(h.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final rooms = snapshot.data ?? [];
        if (rooms.isEmpty) {
          return const Text(
            'No rooms are currently registered for this property.',
            style: TextStyle(color: AppColors.textSecondary),
          );
        }

        final selectedInList = _selectedRoom == null
            ? null
            : rooms.firstWhere(
                (r) => r.roomId == _selectedRoom!.roomId,
                orElse: () => rooms.first,
              );

        return Column(
          children: [
            // Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedRoom != null ? AppColors.primary : AppColors.border,
                  width: _selectedRoom != null ? 1.5 : 1,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RoomModel>(
                  value: selectedInList,
                  dropdownColor: AppColors.surface,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                  hint: const Text(
                    'Tap to choose a room...',
                    style: TextStyle(color: AppColors.textHint, fontSize: 13),
                  ),
                  items: rooms.map((room) {
                    final avail = room.availableBeds > 0;
                    return DropdownMenuItem<RoomModel>(
                      value: room,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: (avail ? AppColors.success : AppColors.error)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.meeting_room_outlined,
                              size: 14,
                              color: avail ? AppColors.success : AppColors.error,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Room ${room.roomNumber} — ${room.roomType.toUpperCase()}',
                                  style: TextStyle(
                                    color: avail ? AppColors.textPrimary : AppColors.textHint,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${room.availableBeds}/${room.capacity} beds  •  PKR ${room.price.toInt()}/mo',
                                  style: TextStyle(
                                    color: avail ? AppColors.textSecondary : AppColors.textHint,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (RoomModel? value) {
                    if (value != null && value.availableBeds > 0) {
                      setState(() { _selectedRoom = value; _bedsBooked = 1; });
                    } else {
                      _showSnack('That room is fully occupied!', AppColors.warning);
                    }
                  },
                ),
              ),
            ),

            if (_selectedRoom != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _statChip(Icons.bed, '${_selectedRoom!.availableBeds} Free', AppColors.success)),
                  const SizedBox(width: 8),
                  Expanded(child: _statChip(Icons.currency_rupee, '${_selectedRoom!.price.toInt()}/mo', AppColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: _statChip(Icons.category_outlined, _selectedRoom!.roomType, AppColors.info)),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Beds & Dates ───────────────────────────────────────────────────
  Widget _buildBedsAndDates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Number of Beds',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [
            _counterBtn(Icons.remove, () { if (_bedsBooked > 1) setState(() => _bedsBooked--); }),
            Expanded(
              child: Center(
                child: Text(
                  '$_bedsBooked Bed${_bedsBooked > 1 ? 's' : ''}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            _counterBtn(Icons.add, () {
              if (_bedsBooked < _selectedRoom!.availableBeds) {
                setState(() => _bedsBooked++);
              } else {
                _showSnack('Cannot exceed available beds!', AppColors.warning);
              }
            }),
          ],
        ),
        const SizedBox(height: 20),

        const Text('Stay Type',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _stayTypeBtn('Monthly Stay', BookingType.monthly, Icons.calendar_month_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _stayTypeBtn('Daily Tourist', BookingType.daily, Icons.date_range_outlined)),
          ],
        ),
        const SizedBox(height: 20),

        if (_bookingType == BookingType.monthly) ...[
          const Text('Check-in Date',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(primary: AppColors.primary)),
                  child: child!,
                ),
              );
              if (date != null) setState(() => _checkIn = date);
            },
            child: _dateTile(
              icon: Icons.calendar_today,
              text: _checkIn != null
                  ? '${_checkIn!.day}/${_checkIn!.month}/${_checkIn!.year}'
                  : 'Tap to pick check-in date',
              active: _checkIn != null,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Duration (Months)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              _counterBtn(Icons.remove, () { if (_months > 1) setState(() => _months--); }),
              Expanded(
                child: Center(
                  child: Text(
                    '$_months Month${_months > 1 ? 's' : ''}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              _counterBtn(Icons.add, () { if (_months < 12) setState(() => _months++); }),
            ],
          ),
        ] else ...[
          const Text('Stay Date Range',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _stayRange ??
                    DateTimeRange(
                      start: DateTime.now().add(const Duration(days: 1)),
                      end: DateTime.now().add(const Duration(days: 4)),
                    ),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(primary: AppColors.primary)),
                  child: child!,
                ),
              );
              if (range != null) {
                setState(() { _stayRange = range; _checkIn = range.start; });
              }
            },
            child: _dateTile(
              icon: Icons.date_range,
              text: _stayRange != null
                  ? '${_stayRange!.start.day}/${_stayRange!.start.month} → '
                    '${_stayRange!.end.day}/${_stayRange!.end.month} '
                    '(${_stayRange!.duration.inDays} days)'
                  : 'Tap to select tourist stay range',
              active: _stayRange != null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _dateTile({required IconData icon, required String text, required bool active}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.border,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (active)
            const Icon(Icons.edit_outlined, color: AppColors.primary, size: 14),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final days = _stayRange?.duration.inDays ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.primaryLight.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('3',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Booking Summary',
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('Review before confirming',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 18),
              ],
            ),
          ),

          _dashes(),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Column(
              children: [
                if (_bookingType == BookingType.monthly) ...[
                  _priceRow('Room', 'Room ${_selectedRoom!.roomNumber}'),
                  _priceRow('Type', _selectedRoom!.roomType.toUpperCase()),
                  _priceRow('Rate per Bed', 'PKR ${_selectedRoom!.price.toInt()}/mo'),
                  _priceRow('Beds', '$_bedsBooked bed${_bedsBooked > 1 ? 's' : ''}'),
                  _priceRow('Duration', '$_months month${_months > 1 ? 's' : ''}'),
                  if (_checkIn != null)
                    _priceRow('Check-in', '${_checkIn!.day}/${_checkIn!.month}/${_checkIn!.year}'),
                ] else ...[
                  _priceRow('Room', 'Room ${_selectedRoom!.roomNumber}'),
                  _priceRow('Daily Rate', 'PKR ${(_selectedRoom!.price / 30.0).toStringAsFixed(0)}/day'),
                  _priceRow('Beds', '$_bedsBooked bed${_bedsBooked > 1 ? 's' : ''}'),
                  _priceRow('Duration', '$days day${days > 1 ? 's' : ''}'),
                  if (_stayRange != null) ...[
                    _priceRow('Check-in',
                        '${_stayRange!.start.day}/${_stayRange!.start.month}/${_stayRange!.start.year}'),
                    _priceRow('Check-out',
                        '${_stayRange!.end.day}/${_stayRange!.end.month}/${_stayRange!.end.year}'),
                  ],
                ],
                _dashes(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(
                      'PKR ${_totalAmount.toInt()}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warning, size: 15),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Booking is pending owner approval. Beds are reserved once confirmed.',
                          style: TextStyle(color: AppColors.warning, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashes() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: List.generate(40, (i) => Expanded(
          child: Container(
            height: 1,
            color: i.isEven ? AppColors.border : Colors.transparent,
          ),
        )),
      ),
    );
  }

  Widget _buildBottomBar() {
    final ready = _canBook;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ready
          ? Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    Text(
                      'PKR ${_totalAmount.toInt()}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _book,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                      label: Text(
                        _submitting ? 'Submitting...' : 'Confirm Booking',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                child: const Text(
                  'Complete steps above to book',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13),
                ),
              ),
            ),
    );
  }

  Widget _stayTypeBtn(String title, BookingType type, IconData icon) {
    final sel = _bookingType == type;
    return GestureDetector(
      onTap: () => setState(() { _bookingType = type; _checkIn = null; _stayRange = null; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: sel ? AppColors.primaryGradient : null,
          color: sel ? null : AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? AppColors.primary : AppColors.border,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: sel ? Colors.white : AppColors.textSecondary, size: 18),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: sel ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
      );

  Widget _priceRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
}

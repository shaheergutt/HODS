import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../models/hostel_model.dart';
import '../../models/review_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/facility_chip.dart';

class HostelDetailScreen extends ConsumerStatefulWidget {
  final String hostelId;
  const HostelDetailScreen({super.key, required this.hostelId});

  @override
  ConsumerState<HostelDetailScreen> createState() => _HostelDetailScreenState();
}

class _HostelDetailScreenState extends ConsumerState<HostelDetailScreen> {
  int _currentImage = 0;
  HostelModel? _hostel;
  List<ReviewModel> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final fs = FirestoreService();
      final hostel = await fs.getHostel(widget.hostelId);
      final reviews = await fs.getHostelReviews(widget.hostelId);
      if (mounted) {
        setState(() {
          _hostel = hostel;
          _reviews = reviews;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading hostel details data: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load hostel details: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _launchMap(HostelModel h) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("${h.name}, ${h.location}, ${h.city}")}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch map tracker.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator()));
    if (_hostel == null) return Scaffold(backgroundColor: AppColors.background, appBar: AppBar(), body: const Center(child: Text('Hostel not found')));

    final h = _hostel!;
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: GestureDetector(
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/student');
                }
              },
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            actions: [
              if (user != null && user.role == UserRole.student)
                GestureDetector(
                  onTap: () async {
                    try {
                      await FirestoreService().toggleFavoriteHostel(user.uid, h.id);
                      final isFav = user.favorites.contains(h.id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isFav ? 'Removed from Wishlist' : 'Added to Wishlist'),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: Icon(
                      user.favorites.contains(h.id) ? Icons.favorite : Icons.favorite_border,
                      color: user.favorites.contains(h.id) ? Colors.red : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  if (h.imageUrls.isNotEmpty)
                    PageView.builder(
                      itemCount: h.imageUrls.length,
                       onPageChanged: (i) => setState(() => _currentImage = i),
                      itemBuilder: (_, i) => CachedNetworkImage(
                        imageUrl: h.imageUrls[i],
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.surface),
                        errorWidget: (_, __, ___) => Container(color: AppColors.surface, child: const Icon(Icons.home_work, size: 64, color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                      child: const Center(child: Icon(Icons.home_work_rounded, size: 80, color: Colors.white)),
                    ),
                  if (h.imageUrls.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(h.imageUrls.length, (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentImage == i ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentImage == i ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Expanded(child: Text('${h.location}, ${h.city}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                          ]),
                        ],
                      )),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('PKR ${h.pricePerMonth.toInt()}', style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text('/month', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    _buildBadge(Icons.star, '${h.rating.toStringAsFixed(1)} (${h.reviewCount})', AppColors.warning),
                    const SizedBox(width: 8),
                    _buildBadge(Icons.bed, '${h.totalRooms} rooms', AppColors.info),
                    const SizedBox(width: 8),
                    _buildBadge(h.genderPolicy == 'Male' ? Icons.male : h.genderPolicy == 'Female' ? Icons.female : Icons.people, h.genderPolicy, AppColors.primary),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('Description'),
                  Text(h.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6)),
                  const SizedBox(height: 16),
                  _buildSection('Facilities'),
                  Wrap(spacing: 8, runSpacing: 8,
                    children: h.facilities.map((f) => FacilityChip(label: f)).toList()),
                  const SizedBox(height: 16),
                  _buildSection('Availability'),
                  Row(children: [
                    _buildAvailabilityChip('Total', h.totalRooms.toString(), AppColors.info),
                    const SizedBox(width: 8),
                    _buildAvailabilityChip('Available', h.availableRooms.toString(), AppColors.success),
                    const SizedBox(width: 8),
                    _buildAvailabilityChip('Occupied', (h.totalRooms - h.availableRooms).toString(), AppColors.error),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('Owner Info'),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      CircleAvatar(backgroundColor: AppColors.primary, child: Text(h.ownerName[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(h.ownerName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        Row(children: [
                          const Icon(Icons.verified, size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text('License: ${h.licenseNumber}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ]),
                      ]),
                    ]),
                  ),
                  
                  // Location Landmarks & Tracker Map Card
                  const SizedBox(height: 20),
                  _buildSection('Location & Surrounding Radar'),
                  _buildLocationRadarCard(h),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSection('Reviews'),
                      if (user != null && user.role == UserRole.student)
                        TextButton.icon(
                          icon: const Icon(Icons.rate_review_outlined, size: 16, color: AppColors.primary),
                          label: const Text('Write a Review', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () => _showAddReviewSheet(context, h, user),
                        ),
                    ],
                  ),
                  if (_reviews.isNotEmpty)
                    ..._reviews.take(5).map((r) => _buildReviewTile(r))
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No reviews yet. Be the first to share your experience!',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic)),
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(h, user),
    );
  }

  /// Role-aware bottom bar:
  /// - Students: Book Room (if available) or No Rooms
  /// - Logged-out users: Sign in to Book
  /// - Owners / Admins: hidden (they view only, never book)
  Widget _buildBottomActionBar(HostelModel h, UserModel? user) {
    // Owners and admins never need the booking bar
    if (user != null && user.role != UserRole.student) {
      return const SizedBox.shrink();
    }

    // No rooms available — show disabled bar for everyone
    if (h.availableRooms == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: CustomButton(
            text: 'No Rooms Available',
            onPressed: null,
          ),
        ),
      );
    }

    // Student / guest: show booking bar
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PKR ${h.pricePerMonth.toInt()}/mo',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PKR ${h.pricePerDay.toInt()}/day',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: CustomButton(
                text: user != null ? 'Book Room' : 'Sign in to Book',
                onPressed: () {
                  if (user != null) {
                    context.push('/student/book/${h.id}');
                  } else {
                    context.push('/login');
                  }
                },
                icon: user != null ? Icons.book_online : Icons.login,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRadarCard(HostelModel h) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // const Row(children: [
        //   Icon(Icons.radar, color: AppColors.primary, size: 20),
        //   SizedBox(width: 8),
        //   Text('Surrounding Proximity Radar', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
        // ]),
        // const SizedBox(height: 8),
        // const Text(
        //   'Match proximity calculations for relative landmark tracking:',
        //   style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
        // ),
        // const SizedBox(height: 16),
        // _buildLandmarkRow(Icons.school, 'FAST / NUST / IQRA University', '1.2 km (5 mins drive)', Colors.teal),
        // const Divider(color: AppColors.border, height: 12),
        // _buildLandmarkRow(Icons.directions_bus, 'Main Transit & Metro Station', '400 meters (6 mins walk)', Colors.orange),
        // const Divider(color: AppColors.border, height: 12),
        // _buildLandmarkRow(Icons.restaurant, 'Local Markaz & Dining Hub', '250 meters (3 mins walk)', Colors.green),
        // const Divider(color: AppColors.border, height: 12),
        // _buildLandmarkRow(Icons.local_hospital, 'Emergency Medical Center', '1.8 km (8 mins drive)', Colors.red),
        //
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _launchMap(h),
            icon: const Icon(Icons.map, color: Colors.white, size: 18),
            label: const Text('Trace Location on Google Maps', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildLandmarkRow(IconData icon, String name, String distance, Color color) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
      Text(distance, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ]);
  }

  void _showAddReviewSheet(BuildContext context, HostelModel h, UserModel user) {
    double rating = 5.0;
    final commentCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Write a Review',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Rating',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starVal = index + 1;
                  return IconButton(
                    icon: Icon(
                      rating >= starVal ? Icons.star : Icons.star_border,
                      color: AppColors.warning,
                      size: 36,
                    ),
                    onPressed: () => setSheetState(() => rating = starVal.toDouble()),
                  );
                }),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your Review',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Share your experience staying here...',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Submit Review',
                  isLoading: submitting,
                  onPressed: () async {
                    if (commentCtrl.text.trim().isEmpty) return;
                    setSheetState(() => submitting = true);
                    final review = ReviewModel(
                      id: '',
                      hostelId: h.id,
                      studentId: user.uid,
                      studentName: user.name,
                      studentImageUrl: user.profileImageUrl,
                      rating: rating,
                      comment: commentCtrl.text.trim(),
                      createdAt: DateTime.now(),
                    );
                    try {
                      await FirestoreService().addReview(review);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Review submitted successfully!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
  );

  Widget _buildBadge(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _buildAvailabilityChip(String label, String count, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(children: [
        Text(count, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ]),
    ),
  );

  Widget _buildReviewTile(ReviewModel r) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(radius: 16, backgroundColor: AppColors.primary, child: Text(r.studentName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))),
        const SizedBox(width: 8),
        Expanded(child: Text(r.studentName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
        Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star : Icons.star_border, size: 14, color: AppColors.warning))),
      ]),
      const SizedBox(height: 6),
      Text(r.comment, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    ]),
  );
}

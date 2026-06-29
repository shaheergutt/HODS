import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../models/hostel_model.dart';
import '../models/user_model.dart';
import '../core/constants/app_colors.dart';

class HostelCard extends StatelessWidget {
  final HostelModel hostel;
  final UserModel? currentUser;

  const HostelCard({
    super.key,
    required this.hostel,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final score = currentUser != null
        ? hostel.recommendationScore(currentUser)
        : null;

    return GestureDetector(
      onTap: () => context.push('/student/hostel/${hostel.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: hostel.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: hostel.imageUrls.first,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _imagePlaceholder(),
                          errorWidget: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
                // Recommendation badge
                if (score != null && score > 60)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${score.toInt()}% Match',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Price tag
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PKR ${_formatPrice(hostel.pricePerMonth)}/mo',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hostel.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: AppColors.secondary, size: 16),
                          const SizedBox(width: 3),
                          Text(
                            hostel.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: AppColors.textHint, size: 14),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${hostel.location}, ${hostel.city}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Facilities
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: hostel.facilities.take(4).map((f) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _facilityColor(f).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: _facilityColor(f).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                              color: _facilityColor(f),
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.bed_outlined,
                          color: AppColors.textHint, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${hostel.availableRooms} rooms available',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Gender policy badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hostel.genderPolicy,
                          style: const TextStyle(
                            color: AppColors.info,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: hostel.availableRooms > 0
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hostel.availableRooms > 0 ? 'Available' : 'Full',
                          style: TextStyle(
                            color: hostel.availableRooms > 0
                                ? AppColors.success
                                : AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.cardGradient,
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apartment, color: AppColors.textHint, size: 48),
          SizedBox(height: 8),
          Text('No Image', style: TextStyle(color: AppColors.textHint)),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toStringAsFixed(0);
  }

  Color _facilityColor(String facility) {
    switch (facility.toLowerCase()) {
      case 'wifi': return AppColors.wifiColor;
      case 'ac': return AppColors.acColor;
      case 'meals': return AppColors.mealsColor;
      case 'laundry': return AppColors.laundryColor;
      case 'parking': return AppColors.parkingColor;
      case 'gym': return AppColors.gymColor;
      case 'cctv':
      case '24/7 security': return AppColors.securityColor;
      case 'water cooler': 
      case 'hot water':
      case 'geyser': return AppColors.waterColor;
      case 'generator': return AppColors.secondary;
      case 'study room': return AppColors.primaryLight;
      default: return AppColors.primary;
    }
  }
}

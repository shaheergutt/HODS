import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';

class ShimmerLoadingWidget extends StatelessWidget {
  final Widget child;

  const ShimmerLoadingWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.border,
      child: child,
    );
  }

  static Widget card({double height = 180, double width = double.infinity, double radius = 16}) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.border,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  static Widget text({double height = 16, double width = 120, double radius = 4}) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.border,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  static Widget circle({double radius = 24}) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.border,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surface,
      ),
    );
  }

  static Widget dashboardSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text(height: 14, width: 80),
                  const SizedBox(height: 8),
                  text(height: 22, width: 140),
                ],
              ),
              circle(radius: 20),
            ],
          ),
          const SizedBox(height: 24),
          card(height: 52, radius: 14),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              4,
              (index) => Column(
                children: [
                  circle(radius: 22),
                  const SizedBox(height: 8),
                  text(height: 10, width: 50),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          text(height: 18, width: 180),
          const SizedBox(height: 16),
          card(height: 180),
          const SizedBox(height: 12),
          card(height: 180),
        ],
      ),
    );
  }
}

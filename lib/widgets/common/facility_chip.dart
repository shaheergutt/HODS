import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class FacilityChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool small;

  const FacilityChip({
    super.key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
    this.small = false,
  });

  IconData _iconForFacility(String label) {
    final l = label.toLowerCase();
    if (l.contains('wifi')) return Icons.wifi;
    if (l.contains('ac') || l.contains('air')) return Icons.ac_unit;
    if (l.contains('meal') || l.contains('food')) return Icons.restaurant;
    if (l.contains('laundry') || l.contains('wash')) return Icons.local_laundry_service;
    if (l.contains('gym') || l.contains('fitness')) return Icons.fitness_center;
    if (l.contains('park')) return Icons.local_parking;
    if (l.contains('cctv') || l.contains('security')) return Icons.security;
    if (l.contains('study') || l.contains('library')) return Icons.menu_book;
    if (l.contains('generator') || l.contains('backup')) return Icons.electric_bolt;
    if (l.contains('water')) return Icons.water_drop;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final chipIcon = icon ?? _iconForFacility(label);
    final double fontSize = small ? 10 : 12;
    final double iconSize = small ? 12 : 14;
    final double hPad = small ? 8 : 12;
    final double vPad = small ? 4 : 6;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              chipIcon,
              size: iconSize,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

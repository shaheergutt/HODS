import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette — Deep Purple/Violet
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFF9D5CF6);
  static const Color primaryDark = Color(0xFF5B21B6);

  // Secondary — Amber/Gold accent
  static const Color secondary = Color(0xFFF59E0B);
  static const Color secondaryLight = Color(0xFFFCD34D);

  // Backgrounds
  static const Color background = Color(0xFF0D0D1A);
  static const Color surface = Color(0xFF13131F);
  static const Color cardColor = Color(0xFF1A1A2E);
  static const Color inputFill = Color(0xFF1E1E32);
  static const Color chipBg = Color(0xFF1E1E32);

  // Borders
  static const Color border = Color(0xFF2A2A42);

  // Text
  static const Color textPrimary = Color(0xFFF1F1F1);
  static const Color textSecondary = Color(0xFFAAABBE);
  static const Color textHint = Color(0xFF6B6C80);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF0D0D1A), Color(0xFF1A0A3B), Color(0xFF0D0D1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Facility chip colors
  static const Color wifiColor = Color(0xFF3B82F6);
  static const Color acColor = Color(0xFF06B6D4);
  static const Color mealsColor = Color(0xFF10B981);
  static const Color laundryColor = Color(0xFF8B5CF6);
  static const Color parkingColor = Color(0xFFF59E0B);
  static const Color gymColor = Color(0xFFEF4444);
  static const Color securityColor = Color(0xFF6366F1);
  static const Color waterColor = Color(0xFF14B8A6);
}

// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Nova UI Theme Tokens & Color System
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Centralized Nova Design System design tokens.
abstract class AppColors {
  // Core Backgrounds
  static const Color background = Color(0xFF070A12);
  static const Color surface = Color(0xFF101420);
  static const Color surface2 = Color(0xFF171C2B);
  static const Color surfaceElevated = Color(0xFF1E2438);
  static const Color surfaceLight = Color(0xFF252540);
  static const Color surfaceLighter = Color(0xFF2E2E4A);

  // Brand Primaries & Accents
  static const Color primary = Color(0xFF7C3AED); // Royal Violet
  static const Color primaryLight = Color(0xFF9061F9);
  static const Color primaryDark = Color(0xFF5B21B6);

  static const Color accent = Color(0xFF22D3EE); // Cyan
  static const Color accentLight = Color(0xFF67E8F9);
  static const Color accentDark = Color(0xFF0891B2);

  static const Color hotPink = Color(0xFFEC4899); // Hot Pink
  static const Color success = Color(0xFF22C55E); // Emerald Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Rose Red

  // Text Hierarchy
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textSubtle = Color(0xFF64748B);

  // Borders & Dividers
  static const Color border = Color(0xFF273044);
  static const Color borderSubtle = Color(0xFF1A2234);
  static const Color borderFocus = Color(0xFF7C3AED);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, hotPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surface, surface2],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient overlayGradient = LinearGradient(
    colors: [Colors.transparent, Color(0xCC070A12), Color(0xF0070A12)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.7, 1.0],
  );

  static const LinearGradient glowGradient = LinearGradient(
    colors: [Color(0x337C3AED), Color(0x1122D3EE), Colors.transparent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Typography and text styles for the Nova UI
abstract class AppTypography {
  static const TextStyle display = TextStyle(
    color: AppColors.textMain,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  static const TextStyle titleLarge = TextStyle(
    color: AppColors.textMain,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle titleMedium = TextStyle(
    color: AppColors.textMain,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.textMain,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle bodyMuted = TextStyle(
    color: AppColors.textMuted,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle label = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static const TextStyle button = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
}

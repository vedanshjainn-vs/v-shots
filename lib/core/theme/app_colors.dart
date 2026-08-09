// ════════════════════════════════════════════════
// V Shots — App Colors
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Centralized color constants.
/// Change these to rebrand the entire app.
abstract class AppColors {
  // Brand
  static const Color accent = Color(0xFFFF4D6A);
  static const Color accentLight = Color(0xFFFF6B8A);
  static const Color accentDark = Color(0xFFE63E5A);

  // Surfaces
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFF252540);
  static const Color surfaceLighter = Color(0xFF2E2E4A);

  // Text
  static const Color textPrimary = Colors.white;
  static final Color textSecondary = Colors.white.withOpacity(0.7);
  static final Color textTertiary = Colors.white.withOpacity(0.5);
  static final Color textMuted = Colors.white.withOpacity(0.3);

  // Gradients
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentLight],
  );

  static LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [accent.withOpacity(0.15), background],
  );
}

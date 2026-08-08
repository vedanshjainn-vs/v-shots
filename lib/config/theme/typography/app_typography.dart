// ════════════════════════════════════════════════
// Project Lyra — Typography System
// ════════════════════════════════════════════════
//
// Beautiful, hierarchical type system.
// Inspired by Apple Music's bold, clear typography.
// Uses system fonts with precise weight/size tuning.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Custom typography definitions for the Lyra design system.
///
/// Follows Material 3 type scale with custom adjustments
/// for a premium, music-oriented UI.
abstract final class AppTypography {
  // ── Font Family ──────────────────────────────
  // System font stack — swap to custom font via pubspec.
  static const String _fontFamily = 'SF Pro Display';
  static const String _fontFamilyFallback = '.SF Pro Display';
  static const String _bodyFontFamily = 'SF Pro Text';
  static const String _bodyFontFallback = '.SF Pro Text';

  // ── Display ──────────────────────────────────
  // Hero headlines — album titles, big moments.
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: [_fontFamilyFallback],
    fontSize: 57,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.12,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: [_fontFamilyFallback],
    fontSize: 45,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.16,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: [_fontFamilyFallback],
    fontSize: 36,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.22,
  );

  // ── Headline ─────────────────────────────────
  // Section titles — "Recently Played", "Top Charts".
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: [_fontFamilyFallback],
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: [_fontFamilyFallback],
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.29,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: [_fontFamilyFallback],
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.33,
  );

  // ── Title ────────────────────────────────────
  // Card titles, dialog headers.
  static const TextStyle titleLarge = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: [_fontFamilyFallback],
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.27,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: [_bodyFontFallback],
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.50,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: [_bodyFontFallback],
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.10,
    height: 1.43,
  );

  // ── Body ─────────────────────────────────────
  // Song titles, descriptions, long-form text.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: [_bodyFontFallback],
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.50,
    height: 1.50,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: [_bodyFontFallback],
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: [_bodyFontFallback],
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.40,
    height: 1.33,
  );

  // ── Label ────────────────────────────────────
  // Buttons, chips, badges, captions.
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: [_bodyFontFallback],
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.10,
    height: 1.43,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: [_bodyFontFallback],
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.50,
    height: 1.33,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: [_bodyFontFallback],
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.50,
    height: 1.45,
  );

  // ── Material 3 TextTheme ─────────────────────
  static const TextTheme textTheme = TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );

  // ── Music-Specific Styles ────────────────────

  /// Large hero text for now-playing / album art overlays.
  static const TextStyle heroTitle = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: [_fontFamilyFallback],
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.10,
  );

  /// Subtle metadata text — artist name, duration, bitrate.
  static const TextStyle metadata = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: [_bodyFontFallback],
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.8,
    height: 1.33,
  );

  /// Caption for time stamps, equalizer labels.
  static const TextStyle caption = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: [_bodyFontFallback],
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
    height: 1.40,
  );
}

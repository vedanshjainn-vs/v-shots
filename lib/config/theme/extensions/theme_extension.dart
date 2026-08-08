// ════════════════════════════════════════════════
// Project Lyra — Custom Theme Extension
// ════════════════════════════════════════════════
//
// Extends Material 3 ThemeData with Lyra-specific
// design tokens: gradients, glass, spacing, radius.
// ════════════════════════════════════════════════

import 'dart:ui';

import 'package:flutter/material.dart';

/// Custom theme tokens beyond Material 3.
///
/// Access anywhere via:
/// ```dart
/// final lyra = Theme.of(context).extension<LyraThemeExtension>()!;
/// ```
class LyraThemeExtension extends ThemeExtension<LyraThemeExtension> {
  const LyraThemeExtension({
    required this.glassColor,
    required this.glassBlur,
    required this.gradientPrimary,
    required this.gradientSurface,
    required this.gradientAccent,
    required this.gradientWarm,
    required this.gradientCool,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.dividerColor,
    required this.badgeColor,
    required this.premiumGold,
    required this.premiumGoldDark,
    required this.shadowColor,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.radiusXLarge,
    required this.radiusCircular,
    required this.spacingXxs,
    required this.spacingXs,
    required this.spacingSm,
    required this.spacingMd,
    required this.spacingLg,
    required this.spacingXl,
    required this.spacingXxl,
  });

  // ── Glass Effect ─────────────────────────────
  final Color glassColor;
  final double glassBlur;

  // ── Gradients ────────────────────────────────
  final LinearGradient gradientPrimary;
  final LinearGradient gradientSurface;
  final LinearGradient gradientAccent;
  final LinearGradient gradientWarm;
  final LinearGradient gradientCool;

  // ── Shimmer ──────────────────────────────────
  final Color shimmerBase;
  final Color shimmerHighlight;

  // ── Misc Colors ──────────────────────────────
  final Color dividerColor;
  final Color badgeColor;
  final Color premiumGold;
  final Color premiumGoldDark;
  final Color shadowColor;

  // ── Radius ───────────────────────────────────
  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;
  final double radiusXLarge;
  final double radiusCircular;

  // ── Spacing ──────────────────────────────────
  final double spacingXxs;
  final double spacingXs;
  final double spacingSm;
  final double spacingMd;
  final double spacingLg;
  final double spacingXl;
  final double spacingXxl;

  // ── Dark Instance ────────────────────────────
  static final dark = LyraThemeExtension(
    glassColor: const Color(0xFF1A1A24).withValues(alpha: 0.6),
    glassBlur: 20.0,
    gradientPrimary: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF4D6A), Color(0xFFFF6B8A)],
    ),
    gradientSurface: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF1A1A24).withValues(alpha: 0.9),
        const Color(0xFF0A0A0F).withValues(alpha: 0.95),
      ],
    ),
    gradientAccent: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB8C0FF), Color(0xFFFF4D6A)],
    ),
    gradientWarm: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFB74D), Color(0xFFFF4D6A)],
    ),
    gradientCool: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
    ),
    shimmerBase: const Color(0xFF1E1E28),
    shimmerHighlight: const Color(0xFF282834),
    dividerColor: const Color(0xFF2A2A38).withValues(alpha: 0.5),
    badgeColor: const Color(0xFFFFB74D),
    premiumGold: const Color(0xFFFFD700),
    premiumGoldDark: const Color(0xFFB8860B),
    shadowColor: const Color(0xFF000000).withValues(alpha: 0.3),
    radiusSmall: 8.0,
    radiusMedium: 12.0,
    radiusLarge: 16.0,
    radiusXLarge: 24.0,
    radiusCircular: 999.0,
    spacingXxs: 2.0,
    spacingXs: 4.0,
    spacingSm: 8.0,
    spacingMd: 16.0,
    spacingLg: 24.0,
    spacingXl: 32.0,
    spacingXxl: 48.0,
  );

  // ── Light Instance ───────────────────────────
  static final light = LyraThemeExtension(
    glassColor: const Color(0xFFFFFFFF).withValues(alpha: 0.7),
    glassBlur: 20.0,
    gradientPrimary: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB02E45), Color(0xFFD44060)],
    ),
    gradientSurface: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFF2ECF0).withValues(alpha: 0.9),
        const Color(0xFFFFFBFF).withValues(alpha: 0.95),
      ],
    ),
    gradientAccent: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF474A80), Color(0xFFB02E45)],
    ),
    gradientWarm: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B5E00), Color(0xFFB02E45)],
    ),
    gradientCool: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
    ),
    shimmerBase: const Color(0xFFE6E0E4),
    shimmerHighlight: const Color(0xFFF2ECF0),
    dividerColor: const Color(0xFFCAC4D0).withValues(alpha: 0.5),
    badgeColor: const Color(0xFF8B5E00),
    premiumGold: const Color(0xFFB8860B),
    premiumGoldDark: const Color(0xFF8B6914),
    shadowColor: const Color(0xFF000000).withValues(alpha: 0.08),
    radiusSmall: 8.0,
    radiusMedium: 12.0,
    radiusLarge: 16.0,
    radiusXLarge: 24.0,
    radiusCircular: 999.0,
    spacingXxs: 2.0,
    spacingXs: 4.0,
    spacingSm: 8.0,
    spacingMd: 16.0,
    spacingLg: 24.0,
    spacingXl: 32.0,
    spacingXxl: 48.0,
  );

  // ── ThemeExtension overrides ─────────────────

  @override
  LyraThemeExtension copyWith({
    Color? glassColor,
    double? glassBlur,
    LinearGradient? gradientPrimary,
    LinearGradient? gradientSurface,
    LinearGradient? gradientAccent,
    LinearGradient? gradientWarm,
    LinearGradient? gradientCool,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? dividerColor,
    Color? badgeColor,
    Color? premiumGold,
    Color? premiumGoldDark,
    Color? shadowColor,
    double? radiusSmall,
    double? radiusMedium,
    double? radiusLarge,
    double? radiusXLarge,
    double? radiusCircular,
    double? spacingXxs,
    double? spacingXs,
    double? spacingSm,
    double? spacingMd,
    double? spacingLg,
    double? spacingXl,
    double? spacingXxl,
  }) {
    return LyraThemeExtension(
      glassColor: glassColor ?? this.glassColor,
      glassBlur: glassBlur ?? this.glassBlur,
      gradientPrimary: gradientPrimary ?? this.gradientPrimary,
      gradientSurface: gradientSurface ?? this.gradientSurface,
      gradientAccent: gradientAccent ?? this.gradientAccent,
      gradientWarm: gradientWarm ?? this.gradientWarm,
      gradientCool: gradientCool ?? this.gradientCool,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      dividerColor: dividerColor ?? this.dividerColor,
      badgeColor: badgeColor ?? this.badgeColor,
      premiumGold: premiumGold ?? this.premiumGold,
      premiumGoldDark: premiumGoldDark ?? this.premiumGoldDark,
      shadowColor: shadowColor ?? this.shadowColor,
      radiusSmall: radiusSmall ?? this.radiusSmall,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      radiusLarge: radiusLarge ?? this.radiusLarge,
      radiusXLarge: radiusXLarge ?? this.radiusXLarge,
      radiusCircular: radiusCircular ?? this.radiusCircular,
      spacingXxs: spacingXxs ?? this.spacingXxs,
      spacingXs: spacingXs ?? this.spacingXs,
      spacingSm: spacingSm ?? this.spacingSm,
      spacingMd: spacingMd ?? this.spacingMd,
      spacingLg: spacingLg ?? this.spacingLg,
      spacingXl: spacingXl ?? this.spacingXl,
      spacingXxl: spacingXxl ?? this.spacingXxl,
    );
  }

  @override
  LyraThemeExtension lerp(covariant ThemeExtension<LyraThemeExtension>? other, double t) {
    if (other is! LyraThemeExtension) return this;
    return LyraThemeExtension(
      glassColor: Color.lerp(glassColor, other.glassColor, t)!,
      glassBlur: lerpDouble(glassBlur, other.glassBlur, t)!,
      gradientPrimary: LinearGradient.lerp(gradientPrimary, other.gradientPrimary, t)!,
      gradientSurface: LinearGradient.lerp(gradientSurface, other.gradientSurface, t)!,
      gradientAccent: LinearGradient.lerp(gradientAccent, other.gradientAccent, t)!,
      gradientWarm: LinearGradient.lerp(gradientWarm, other.gradientWarm, t)!,
      gradientCool: LinearGradient.lerp(gradientCool, other.gradientCool, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      badgeColor: Color.lerp(badgeColor, other.badgeColor, t)!,
      premiumGold: Color.lerp(premiumGold, other.premiumGold, t)!,
      premiumGoldDark: Color.lerp(premiumGoldDark, other.premiumGoldDark, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall, t)!,
      radiusMedium: lerpDouble(radiusMedium, other.radiusMedium, t)!,
      radiusLarge: lerpDouble(radiusLarge, other.radiusLarge, t)!,
      radiusXLarge: lerpDouble(radiusXLarge, other.radiusXLarge, t)!,
      radiusCircular: lerpDouble(radiusCircular, other.radiusCircular, t)!,
      spacingXxs: lerpDouble(spacingXxs, other.spacingXxs, t)!,
      spacingXs: lerpDouble(spacingXs, other.spacingXs, t)!,
      spacingSm: lerpDouble(spacingSm, other.spacingSm, t)!,
      spacingMd: lerpDouble(spacingMd, other.spacingMd, t)!,
      spacingLg: lerpDouble(spacingLg, other.spacingLg, t)!,
      spacingXl: lerpDouble(spacingXl, other.spacingXl, t)!,
      spacingXxl: lerpDouble(spacingXxl, other.spacingXxl, t)!,
    );
  }
}

// ════════════════════════════════════════════════
// Project Lyra — Light Color Scheme
// ════════════════════════════════════════════════
//
// Clean, airy palette for light mode.
// Maintains brand identity from dark scheme.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Light mode color tokens.
abstract final class LightColorScheme {
  // ── Primary ─────────────────────────────────
  static const Color primary = Color(0xFFB02E45);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFFD9DE);
  static const Color onPrimaryContainer = Color(0xFF3D0A15);

  // ── Secondary ───────────────────────────────
  static const Color secondary = Color(0xFF474A80);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFDCE0FF);
  static const Color onSecondaryContainer = Color(0xFF1D1F33);

  // ── Tertiary ────────────────────────────────
  static const Color tertiary = Color(0xFF8B5E00);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFFFDDB3);
  static const Color onTertiaryContainer = Color(0xFF2D1600);

  // ── Error ───────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF410002);

  // ── Surfaces ────────────────────────────────
  static const Color surface = Color(0xFFFFFBFF);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color surfaceDim = Color(0xFFDED8DC);
  static const Color surfaceBright = Color(0xFFFFFBFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF8F1F5);
  static const Color surfaceContainer = Color(0xFFF2ECF0);
  static const Color surfaceContainerHigh = Color(0xFFECE6EA);
  static const Color surfaceContainerHighest = Color(0xFFE6E0E4);
  static const Color onSurfaceVariant = Color(0xFF49454F);

  // ── Outline ─────────────────────────────────
  static const Color outline = Color(0xFF79747E);
  static const Color outlineVariant = Color(0xFFCAC4D0);

  // ── Inverse ─────────────────────────────────
  static const Color inverseSurface = Color(0xFF313033);
  static const Color onInverseSurface = Color(0xFFF4EFF4);
  static const Color inversePrimary = Color(0xFFFFB3BD);

  // ── Scrim / Shadow ──────────────────────────
  static const Color scrim = Color(0xFF000000);
  static const Color shadow = Color(0xFF000000);

  // ── Full ColorScheme ────────────────────────
  static const ColorScheme scheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    surfaceDim: surfaceDim,
    surfaceBright: surfaceBright,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    inverseSurface: inverseSurface,
    onInverseSurface: onInverseSurface,
    inversePrimary: inversePrimary,
    scrim: scrim,
    shadow: shadow,
  );
}

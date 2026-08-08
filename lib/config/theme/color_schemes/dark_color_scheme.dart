// ════════════════════════════════════════════════
// Project Lyra — Dark Color Scheme
// ════════════════════════════════════════════════
//
// Deep, immersive palette inspired by Apple Music.
// Rich blacks, subtle grays, vibrant accent.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Dark mode color tokens.
///
/// Based on Material 3's [ColorScheme] with custom
/// brand colors for the Lyra experience.
abstract final class DarkColorScheme {
  // ── Primary (Brand Accent) ───────────────────
  // A refined coral-red — warm, premium, distinctive.
  static const Color primary = Color(0xFFFF4D6A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF3D0A15);
  static const Color onPrimaryContainer = Color(0xFFFFB3BD);

  // ── Secondary ───────────────────────────────
  // Soft lavender for secondary actions.
  static const Color secondary = Color(0xFFB8C0FF);
  static const Color onSecondary = Color(0xFF1D1F33);
  static const Color secondaryContainer = Color(0xFF2A2D45);
  static const Color onSecondaryContainer = Color(0xFFDCE0FF);

  // ── Tertiary ────────────────────────────────
  // Warm gold for premium / highlight elements.
  static const Color tertiary = Color(0xFFFFB74D);
  static const Color onTertiary = Color(0xFF2D1600);
  static const Color tertiaryContainer = Color(0xFF3D2200);
  static const Color onTertiaryContainer = Color(0xFFFFDDB3);

  // ── Error ───────────────────────────────────
  static const Color error = Color(0xFFFF6B6B);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFF3D0A0A);
  static const Color onErrorContainer = Color(0xFFFFB3B3);

  // ── Surfaces ────────────────────────────────
  // Ultra-dark surfaces for depth and contrast.
  static const Color surface = Color(0xFF0A0A0F);
  static const Color onSurface = Color(0xFFE6E1E5);
  static const Color surfaceDim = Color(0xFF06060A);
  static const Color surfaceBright = Color(0xFF1A1A24);
  static const Color surfaceContainerLowest = Color(0xFF050508);
  static const Color surfaceContainerLow = Color(0xFF0F0F16);
  static const Color surfaceContainer = Color(0xFF14141C);
  static const Color surfaceContainerHigh = Color(0xFF1E1E28);
  static const Color surfaceContainerHighest = Color(0xFF282834);
  static const Color onSurfaceVariant = Color(0xFFCAC4D0);

  // ── Outline ─────────────────────────────────
  static const Color outline = Color(0xFF444454);
  static const Color outlineVariant = Color(0xFF2A2A38);

  // ── Inverse ─────────────────────────────────
  static const Color inverseSurface = Color(0xFFE6E1E5);
  static const Color onInverseSurface = Color(0xFF1C1B1F);
  static const Color inversePrimary = Color(0xFFB02E45);

  // ── Scrim / Shadow ──────────────────────────
  static const Color scrim = Color(0xFF000000);
  static const Color shadow = Color(0xFF000000);

  // ── Full Material 3 ColorScheme ─────────────
  static const ColorScheme scheme = ColorScheme(
    brightness: Brightness.dark,
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

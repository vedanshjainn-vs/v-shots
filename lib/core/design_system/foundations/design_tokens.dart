// ════════════════════════════════════════════════
// Project Lyra — Design Tokens
// ════════════════════════════════════════════════
//
// Complete design token system.
// Single source of truth for all design values.
// Supports light/dark themes and dynamic colors.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Complete set of design tokens for the Lyra design system.
///
/// Access via `DesignTokens.of(context)` or through
/// theme extensions.
abstract final class DesignTokens {
  // ── Spacing Scale ────────────────────────────
  static const double space0 = 0;
  static const double spaceXxs = 2;
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double spaceXxl = 48;
  static const double spaceXxxl = 64;
  static const double space96 = 96;

  // ── Radius Scale ─────────────────────────────
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusXxl = 32;
  static const double radiusFull = 999;

  // ── Elevation Scale ──────────────────────────
  static const double elevation0 = 0;
  static const double elevation1 = 1;
  static const double elevation2 = 2;
  static const double elevation3 = 3;
  static const double elevation4 = 4;
  static const double elevation6 = 6;
  static const double elevation8 = 8;
  static const double elevation12 = 12;
  static const double elevation16 = 16;
  static const double elevation24 = 24;

  // ── Animation Durations ──────────────────────
  static const Duration durationInstant = Duration(milliseconds: 100);
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationSlowest = Duration(milliseconds: 800);

  // ── Animation Curves ─────────────────────────
  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveEnter = Curves.easeOutCubic;
  static const Curve curveExit = Curves.easeInCubic;
  static const Curve curveBounce = Curves.elasticOut;
  static const Curve curveSpring = Curves.easeOutBack;

  // ── Breakpoints ──────────────────────────────
  static const double breakpointMobile = 0;
  static const double breakpointTablet = 600;
  static const double breakpointDesktop = 1200;
  static const double breakpointWide = 1600;

  // ── Component Sizes ──────────────────────────
  static const double buttonHeightSm = 36;
  static const double buttonHeightMd = 48;
  static const double buttonHeightLg = 56;
  static const double iconSizeSm = 16;
  static const double iconSizeMd = 24;
  static const double iconSizeLg = 32;
  static const double iconSizeXl = 48;
  static const double avatarSizeSm = 32;
  static const double avatarSizeMd = 48;
  static const double avatarSizeLg = 64;
  static const double avatarSizeXl = 96;
  static const double bottomNavHeight = 64;
  static const double miniPlayerHeight = 64;
  static const double appBarHeight = 56;
  static const double searchBarHeight = 48;
  static const double cardMinWidth = 140;
  static const double cardMaxWidth = 200;

  // ── Music-Specific Sizes ─────────────────────
  static const double artworkSizeSm = 48;
  static const double artworkSizeMd = 120;
  static const double artworkSizeLg = 200;
  static const double artworkSizeXl = 300;
  static const double playerArtworkSize = 340;
  static const double progressBarHeight = 3;
  static const double volumeBarHeight = 3;
  static const double playButtonSize = 64;
  static const double skipButtonSize = 48;
}

/// Responsive spacing that scales with screen size.
class ResponsiveSpacing {
  const ResponsiveSpacing(this.context);

  final BuildContext context;

  double get _width => MediaQuery.of(context).size.width;
  bool get _isMobile => _width < DesignTokens.breakpointTablet;
  bool get _isTablet => _width >= DesignTokens.breakpointTablet && _width < DesignTokens.breakpointDesktop;

  double get xs => _isMobile ? 4 : 6;
  double get sm => _isMobile ? 8 : 12;
  double get md => _isMobile ? 16 : 24;
  double get lg => _isMobile ? 24 : 32;
  double get xl => _isMobile ? 32 : 48;
  double get xxl => _isMobile ? 48 : 64;

  /// Horizontal padding based on screen size.
  double get horizontalPadding => _isMobile ? 16 : _isTablet ? 32 : 48;

  /// Max content width for centered layouts.
  double get maxContentWidth => 1200;
}

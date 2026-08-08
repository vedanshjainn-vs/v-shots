// ════════════════════════════════════════════════
// Project Lyra — Responsive Mixin
// ════════════════════════════════════════════════
//
// Provides responsive breakpoints and layout
// helpers for widgets that need to adapt.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Mixin for responsive layout calculations.
///
/// Use in StatefulWidgets or State classes.
mixin ResponsiveMixin<T extends StatefulWidget> on State<T> {
  /// Current screen width.
  double get screenWidth => MediaQuery.of(context).size.width;

  /// Current screen height.
  double get screenHeight => MediaQuery.of(context).size.height;

  /// Whether the device is in portrait mode.
  bool get isPortrait =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  /// Whether the device is a phone (< 600px).
  bool get isMobile => screenWidth < 600;

  /// Whether the device is a tablet (600-1200px).
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;

  /// Whether the device is a desktop/large tablet (>= 1200px).
  bool get isDesktop => screenWidth >= 1200;

  /// Number of grid columns based on screen width.
  int get gridColumns {
    if (isDesktop) return 5;
    if (isTablet) return 3;
    return 2;
  }

  /// Horizontal padding based on screen size.
  double get horizontalPadding {
    if (isDesktop) return 48;
    if (isTablet) return 32;
    return 16;
  }

  /// Max content width for centered layouts.
  double get maxContentWidth => 1200;

  /// Responsive value based on screen size.
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }
}

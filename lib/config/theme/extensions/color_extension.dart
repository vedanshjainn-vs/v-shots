// ════════════════════════════════════════════════
// Project Lyra — Color Context Extension
// ════════════════════════════════════════════════
//
// Convenience accessors for theme colors from
// BuildContext. Avoids repetitive Theme.of() calls.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Quick access to theme colors from any [BuildContext].
///
/// ```dart
/// // Before:
/// Theme.of(context).colorScheme.primary
///
/// // After:
/// context.colors.primary
/// ```
extension ColorContextExtension on BuildContext {
  /// Shorthand for [ColorScheme].
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Shorthand for [TextTheme].
  TextTheme get textStyles => Theme.of(this).textTheme;

  /// Whether the current theme is dark mode.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Whether the current theme is light mode.
  bool get isLightMode => !isDarkMode;
}

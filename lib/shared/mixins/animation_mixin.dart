// ════════════════════════════════════════════════
// Project Lyra — Animation Mixin
// ════════════════════════════════════════════════
//
// Reusable animation patterns: fade, slide, scale.
// Reduces boilerplate for common animations.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Mixin for common animation patterns.
///
/// Use in StatefulWidgets that need animations.
mixin AnimationMixin<T extends StatefulWidget> on State<T>
    with SingleTickerProviderStateMixin<T> {
  late AnimationController animationController;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  /// Fade-in animation.
  Animation<double> get fadeIn => CurvedAnimation(
        parent: animationController,
        curve: Curves.easeInOut,
      );

  /// Slide-up animation.
  Animation<Offset> get slideUp => Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOutCubic,
      ));

  /// Scale animation.
  Animation<double> get scaleUp => Tween<double>(
        begin: 0.9,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOutCubic,
      ));

  /// Start the animation.
  void forward() => animationController.forward();

  /// Reverse the animation.
  void reverse() => animationController.reverse();

  /// Animate to a specific value.
  void animateTo(double value) => animationController.animateTo(value);

  /// Repeat the animation.
  void repeat({bool reverse = false}) =>
      animationController.repeat(reverse: reverse);
}

// ════════════════════════════════════════════════
// Project Lyra — Glass Container
// ════════════════════════════════════════════════
//
// Glassmorphism effect: frosted glass with blur,
// subtle border, and translucent background.
// Apple Music-inspired premium aesthetic.
// ════════════════════════════════════════════════

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/theme_extension.dart';

/// A frosted glass container with blur effect.
///
/// Use for overlays, mini player, floating cards,
/// and any element that needs a premium glass feel.
///
/// ```dart
/// GlassContainer(
///   child: Text('Frosted content'),
/// )
/// ```
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    required this.child,
    this.blur = 20,
    this.opacity = 0.15,
    this.borderRadius,
    this.border,
    this.padding,
    this.margin,
    this.width,
    this.height,
    super.key,
  });

  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final lyra = Theme.of(context).extension<LyraThemeExtension>()!;
    final effectiveRadius = borderRadius ??
        BorderRadius.circular(lyra.radiusLarge);

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: lyra.glassColor.withValues(alpha: opacity),
            borderRadius: effectiveRadius,
            border: border ??
                Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.5,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Project Lyra — Gradient Card
// ════════════════════════════════════════════════
//
// Card with dynamic gradient background.
// For featured content, recently played, etc.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// A card with a gradient background.
///
/// Used for featured content, highlighted sections,
/// and CTA cards.
class GradientCard extends StatelessWidget {
  const GradientCard({
    required this.child,
    this.onTap,
    this.gradient,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.shadow = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;
    final effectiveRadius = borderRadius ??
        BorderRadius.circular(lyra.radiusLarge);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: margin,
        padding: padding ?? EdgeInsets.all(lyra.spacingMd),
        decoration: BoxDecoration(
          gradient: gradient ?? lyra.gradientPrimary,
          borderRadius: effectiveRadius,
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

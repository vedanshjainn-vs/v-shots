// ════════════════════════════════════════════════
// Project Lyra — Glass Card
// ════════════════════════════════════════════════
//
// Premium card with glass effect, rounded corners,
// and optional gradient overlay. Apple Music feel.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/theme_extension.dart';
import '../glass/glass_container.dart';

/// A premium card with glass effect.
///
/// Use for featured content, now-playing, and
/// highlight sections in the UI.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.onTap,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.gradient,
    this.borderRadius,
    this.blur = 15,
    this.opacity = 0.12,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final lyra = Theme.of(context).extension<LyraThemeExtension>()!;

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        blur: blur,
        opacity: opacity,
        borderRadius: borderRadius ??
            BorderRadius.circular(lyra.radiusLarge),
        padding: padding ?? EdgeInsets.all(lyra.spacingMd),
        width: width,
        height: height,
        child: gradient != null
            ? ShaderMask(
                shaderCallback: (bounds) => gradient!.createShader(bounds),
                blendMode: BlendMode.srcATop,
                child: child,
              )
            : child,
      ),
    );
  }
}

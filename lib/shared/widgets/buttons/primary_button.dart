// ════════════════════════════════════════════════
// Project Lyra — Primary Button
// ════════════════════════════════════════════════
//
// Main CTA button with gradient support,
// loading state, and haptic feedback.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Primary action button.
///
/// Used for main CTAs: "Play", "Sign Up", "Subscribe".
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.text,
    this.onTap,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.height = 52,
    this.borderRadius,
    this.gradient,
    this.textColor,
    this.fontSize,
    super.key,
  });

  final String text;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final double height;
  final BorderRadius? borderRadius;
  final Gradient? gradient;
  final Color? textColor;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;
    final isDisabled = onTap == null || isLoading;
    final effectiveRadius = borderRadius ??
        BorderRadius.circular(lyra.radiusLarge);

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap?.call();
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          height: height,
          constraints: isExpanded ? null : const BoxConstraints(minWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: gradient ?? lyra.gradientPrimary,
            borderRadius: effectiveRadius,
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor ?? colors.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: textColor ?? colors.onPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          color: textColor ?? colors.onPrimary,
                          fontSize: fontSize ?? 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Project Lyra — LyraButton
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

enum LyraButtonType { primary, secondary, text, icon }

/// Premium button with gradient support, loading state, and haptic feedback.
class LyraButton extends StatelessWidget {
  const LyraButton({
    required this.text,
    super.key,
    this.onTap,
    this.type = LyraButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.height = 52,
    this.gradient,
    this.borderRadius,
  });

  final String text;
  final VoidCallback? onTap;
  final LyraButtonType type;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final double height;
  final Gradient? gradient;
  final BorderRadius? BorderRadius;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;
    final isDisabled = onTap == null || isLoading;

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
            gradient: type == LyraButtonType.primary
                ? (gradient ?? lyra.gradientPrimary)
                : null,
            color: type == LyraButtonType.secondary
                ? colors.surfaceContainerHighest
                : null,
            borderRadius: BorderRadius ?? BorderRadius.circular(lyra.radiusLarge),
            border: type == LyraButtonType.secondary
                ? Border.all(color: colors.outline, width: 1.5)
                : null,
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: colors.onPrimary, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          color: type == LyraButtonType.primary
                              ? colors.onPrimary
                              : colors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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

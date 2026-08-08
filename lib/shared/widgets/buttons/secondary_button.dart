// ════════════════════════════════════════════════
// Project Lyra — Secondary Button
// ════════════════════════════════════════════════
//
// Outlined / subtle button for secondary actions.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Secondary / outlined button.
///
/// Used for "Cancel", "Skip", "View All" actions.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.text,
    this.onTap,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.height = 52,
    this.borderColor,
    this.textColor,
    super.key,
  });

  final String text;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final double height;
  final Color? borderColor;
  final Color? textColor;

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
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(lyra.radiusLarge),
            border: Border.all(
              color: borderColor ?? colors.outline,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor ?? colors.onSurface,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: textColor ?? colors.onSurface,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          color: textColor ?? colors.onSurface,
                          fontSize: 16,
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

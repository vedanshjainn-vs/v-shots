// ════════════════════════════════════════════════
// Project Lyra — Icon Action Button
// ════════════════════════════════════════════════
//
// Icon-only button with haptic feedback.
// For like, share, download actions.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme/extensions/color_extension.dart';

/// Icon-only action button with optional label.
class IconActionButton extends StatelessWidget {
  const IconActionButton({
    required this.icon,
    this.onTap,
    this.activeIcon,
    this.isActive = false,
    this.activeColor,
    this.inactiveColor,
    this.size = 24,
    this.label,
    super.key,
  });

  final IconData icon;
  final IconData? activeIcon;
  final VoidCallback? onTap;
  final bool isActive;
  final Color? activeColor;
  final Color? inactiveColor;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effectiveColor = isActive
        ? (activeColor ?? colors.primary)
        : (inactiveColor ?? colors.onSurfaceVariant);

    return GestureDetector(
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap!();
            }
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? (activeIcon ?? icon) : icon,
            color: effectiveColor,
            size: size,
          ),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

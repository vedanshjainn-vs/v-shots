// ════════════════════════════════════════════════
// Project Lyra — Empty State Widget
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';
import '../../../config/theme/typography/app_typography.dart';

/// Empty state with icon, message, and optional action.
class LyraEmptyState extends StatelessWidget {
  const LyraEmptyState({
    required this.message,
    super.key,
    this.icon = Icons.inbox_rounded,
    this.title,
    this.actionText,
    this.onAction,
  });

  final IconData icon;
  final String? title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(lyra.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
            SizedBox(height: lyra.spacingLg),
            if (title != null) ...[
              Text(
                title!,
                style: AppTypography.headlineSmall.copyWith(color: colors.onSurface),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: lyra.spacingSm),
            ],
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              SizedBox(height: lyra.spacingLg),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

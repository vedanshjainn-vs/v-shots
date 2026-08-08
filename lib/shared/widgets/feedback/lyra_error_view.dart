// ════════════════════════════════════════════════
// Project Lyra — Error View Widget
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';
import '../../../config/theme/typography/app_typography.dart';

/// Error state with message and retry button.
class LyraErrorView extends StatelessWidget {
  const LyraErrorView({
    required this.message,
    super.key,
    this.title = 'Something went wrong',
    this.onRetry,
    this.retryText = 'Try Again',
    this.icon = Icons.error_outline_rounded,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: lyra.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colors.error.withValues(alpha: 0.6)),
            SizedBox(height: lyra.spacingLg),
            Text(
              title,
              style: AppTypography.headlineSmall.copyWith(color: colors.onSurface),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: lyra.spacingSm),
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SizedBox(height: lyra.spacingXl),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

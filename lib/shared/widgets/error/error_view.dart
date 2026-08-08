// ════════════════════════════════════════════════
// Project Lyra — Error View
// ════════════════════════════════════════════════
//
// Consistent error display with retry option.
// Full-screen and inline variants.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';
import '../../../config/theme/typography/app_typography.dart';

/// Full-screen error state with retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    this.retryText = 'Try Again',
    this.icon = Icons.error_outline_rounded,
    super.key,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;
  final String retryText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lyra = context.lyra;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: lyra.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon
            Icon(
              icon,
              size: 64,
              color: colors.error.withValues(alpha: 0.6),
            ),
            SizedBox(height: lyra.spacingLg),

            // Title
            Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: lyra.spacingSm),

            // Message
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: lyra.spacingXl),

            // Retry button
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryText),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact inline error with retry.
class InlineError extends StatelessWidget {
  const InlineError({
    required this.message,
    this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

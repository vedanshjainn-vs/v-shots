// ════════════════════════════════════════════════
// Project Lyra — Loading Indicator
// ════════════════════════════════════════════════
//
// Consistent loading states across the app.
// Full-screen, inline, and overlay variants.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';

/// Full-screen loading state with optional message.
class FullScreenLoader extends StatelessWidget {
  const FullScreenLoader({
    this.message,
    super.key,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: colors.primary,
            strokeWidth: 2.5,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small inline loader for buttons and lists.
class InlineLoader extends StatelessWidget {
  const InlineLoader({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

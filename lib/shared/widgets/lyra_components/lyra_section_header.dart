// ════════════════════════════════════════════════
// Project Lyra — LyraSectionHeader
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Section header with title and optional action.
class LyraSectionHeader extends StatelessWidget {
  const LyraSectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.onViewAll,
    this.actionText = 'See All',
    this.padding,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;
  final String actionText;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Padding(
      padding: padding ?? EdgeInsets.symmetric(horizontal: lyra.spacingMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: lyra.spacingXxs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: lyra.spacingSm,
                  vertical: lyra.spacingXs,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionText,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

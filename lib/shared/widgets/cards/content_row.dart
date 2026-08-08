// ════════════════════════════════════════════════
// Project Lyra — Content Row
// ════════════════════════════════════════════════
//
// Horizontal scrollable row with section header.
// Standard pattern for carousels: "Recently Played",
// "Top Charts", "Made For You".
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Horizontal content carousel with title and optional action.
///
/// ```dart
/// ContentRow(
///   title: 'Recently Played',
///   onViewAll: () {},
///   children: [MediaCard(...), MediaCard(...)],
/// )
/// ```
class ContentRow extends StatelessWidget {
  const ContentRow({
    required this.title,
    required this.children,
    this.onViewAll,
    this.subtitle,
    this.padding,
    this.spacing = 12.0,
    this.height,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final VoidCallback? onViewAll;
  final EdgeInsetsGeometry? padding;
  final double spacing;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ───────────────────
        Padding(
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
                    'View All',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),

        SizedBox(height: lyra.spacingMd),

        // ── Scrollable Content ───────────────
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: padding ?? EdgeInsets.symmetric(horizontal: lyra.spacingMd),
            itemCount: children.length,
            separatorBuilder: (_, __) => SizedBox(width: spacing),
            itemBuilder: (context, index) => children[index],
          ),
        ),
      ],
    );
  }
}

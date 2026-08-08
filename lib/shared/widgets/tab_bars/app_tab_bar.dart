// ════════════════════════════════════════════════
// Project Lyra — Tab Bar
// ════════════════════════════════════════════════
//
// Pill-style segmented tabs.
// Apple Music-inspired tab design.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Pill-style tab bar for content filtering.
///
/// Used in search results, library, and discover.
class PillTabBar extends StatelessWidget {
  const PillTabBar({
    required this.tabs,
    required this.onTabSelected,
    this.selectedIndex = 0,
    super.key,
  });

  final List<String> tabs;
  final ValueChanged<int> onTabSelected;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => SizedBox(width: lyra.spacingSm),
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;

          return GestureDetector(
            onTap: () => onTabSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.onSurface
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(lyra.radiusCircular),
              ),
              child: Text(
                tabs[index],
                style: TextStyle(
                  color: isSelected ? colors.surface : colors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

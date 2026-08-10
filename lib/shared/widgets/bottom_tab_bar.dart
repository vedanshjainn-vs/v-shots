// ═════════════════════════════════════════════════════════════════════════════
// V Shots — BottomTabBar (Nova Music Design System)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BottomTabBar extends StatelessWidget {
  const BottomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.hasUnreadNotifications = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool hasUnreadNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTabItem(
                index: 0,
                icon: Icons.home_filled,
                inactiveIcon: Icons.home_outlined,
                label: 'Home',
              ),
              _buildTabItem(
                index: 1,
                icon: Icons.auto_awesome_rounded,
                inactiveIcon: Icons.auto_awesome_outlined,
                label: 'Discover',
              ),
              _buildCreateButton(),
              _buildTabItem(
                index: 3,
                icon: Icons.search_rounded,
                inactiveIcon: Icons.search_outlined,
                label: 'Search',
              ),
              _buildTabItem(
                index: 4,
                icon: Icons.person_rounded,
                inactiveIcon: Icons.person_outline_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required IconData inactiveIcon,
    required String label,
    bool hasBadge = false,
  }) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? icon : inactiveIcon,
                  size: 24,
                  color: isSelected ? AppColors.accent : AppColors.textMuted,
                ),
                if (hasBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.hotPink,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.textMain : AppColors.textSubtle,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: () => onTap(2),
      child: Container(
        width: 44,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

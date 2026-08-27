// ═════════════════════════════════════════════════════════════════════════════
// V Shots — ProfileStats (Nova Design System)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ProfileStats extends StatelessWidget {
  const ProfileStats({
    super.key,
    required this.shotsCount,
    required this.followersCount,
    required this.followingCount,
    this.likesCount = 0,
  });

  final int shotsCount;
  final int followersCount;
  final int followingCount;
  final int likesCount;

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat('Shots', _formatNumber(shotsCount)),
          _buildDivider(),
          _buildStat('Followers', _formatNumber(followersCount)),
          _buildDivider(),
          _buildStat('Following', _formatNumber(followingCount)),
          if (likesCount > 0) ...[
            _buildDivider(),
            _buildStat('Likes', _formatNumber(likesCount)),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textMain,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 24, color: AppColors.border);
  }
}

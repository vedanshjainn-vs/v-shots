// ═════════════════════════════════════════════════════════════════════════════
// V Shots — AppAvatar (Nova Design System)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.avatarUrl,
    this.name = '',
    this.size = 44,
    this.showBorder = true,
    this.hasGradientBorder = false,
    this.onTap,
  });

  final String? avatarUrl;
  final String name;
  final double size;
  final bool showBorder;
  final bool hasGradientBorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'V';

    Widget innerAvatar;
    if (hasImage) {
      innerAvatar = CachedNetworkImage(
        imageUrl: avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppColors.surface2,
          child: const Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildInitials(initials),
      );
    } else {
      innerAvatar = _buildInitials(initials);
    }

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: innerAvatar,
    );

    if (hasGradientBorder) {
      content = Container(
        width: size + 4,
        height: size + 4,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
        ),
        child: content,
      );
    } else if (showBorder) {
      content = Container(
        width: size + 2,
        height: size + 2,
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: content,
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  Widget _buildInitials(String initials) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.surface2, AppColors.surfaceElevated],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: AppColors.textMain,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

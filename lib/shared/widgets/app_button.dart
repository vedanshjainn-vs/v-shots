// ═════════════════════════════════════════════════════════════════════════════
// V Shots — AppButton (Nova Design System)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, hotPink, danger }
enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final double height;
    final double fontSize;
    final EdgeInsets padding;
    final double radius;

    switch (size) {
      case AppButtonSize.small:
        height = 36;
        fontSize = 13;
        padding = const EdgeInsets.symmetric(horizontal: 14);
        radius = 18;
        break;
      case AppButtonSize.large:
        height = 54;
        fontSize = 16;
        padding = const EdgeInsets.symmetric(horizontal: 24);
        radius = 27;
        break;
      case AppButtonSize.medium:
        height = 46;
        fontSize = 14;
        padding = const EdgeInsets.symmetric(horizontal: 20);
        radius = 23;
        break;
    }

    final isEnabled = onPressed != null && !isLoading;

    final Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: fontSize + 3, color: _getTextColor()),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(
              color: _getTextColor(),
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );

    Decoration decoration;
    switch (variant) {
      case AppButtonVariant.primary:
        decoration = BoxDecoration(
          gradient: isEnabled ? AppColors.primaryGradient : null,
          color: isEnabled ? null : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        );
        break;
      case AppButtonVariant.hotPink:
        decoration = BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(
                  colors: [AppColors.hotPink, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isEnabled ? null : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.hotPink.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        );
        break;
      case AppButtonVariant.secondary:
        decoration = BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.border, width: 1),
        );
        break;
      case AppButtonVariant.outline:
        decoration = BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isEnabled ? AppColors.primaryLight : AppColors.border,
            width: 1.5,
          ),
        );
        break;
      case AppButtonVariant.danger:
        decoration = BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        );
        break;
      case AppButtonVariant.ghost:
        decoration = BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
        );
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(radius),
        splashColor: Colors.white.withValues(alpha: 0.1),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Ink(
          height: height,
          padding: padding,
          decoration: decoration,
          child: content,
        ),
      ),
    );
  }

  Color _getTextColor() {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.hotPink:
        return Colors.white;
      case AppButtonVariant.secondary:
        return AppColors.textMain;
      case AppButtonVariant.outline:
        return AppColors.accent;
      case AppButtonVariant.danger:
        return AppColors.error;
      case AppButtonVariant.ghost:
        return AppColors.textMuted;
    }
  }
}

// ════════════════════════════════════════════════
// Project Lyra — App Bar
// ════════════════════════════════════════════════
//
// Premium app bar with blur effect, gradient
// support, and consistent styling.
// ════════════════════════════════════════════════

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Premium app bar with optional blur and gradient.
class LyraAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LyraAppBar({
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.showBackButton = true,
    this.blur = false,
    this.gradient,
    this.backgroundColor,
    this.centerTitle = true,
    this.elevation = 0,
    this.bottom,
    this.height = 56,
    super.key,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool blur;
  final Gradient? gradient;
  final Color? backgroundColor;
  final bool centerTitle;
  final double elevation;
  final PreferredSizeWidget? bottom;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(
        height + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lyra = context.lyra;

    final appBar = AppBar(
      title: titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: Theme.of(context).textTheme.titleLarge,
                )
              : null),
      leading: leading,
      actions: actions,
      automaticallyImplyLeading: showBackButton,
      centerTitle: centerTitle,
      elevation: elevation,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      bottom: bottom,
    );

    if (blur) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: appBar,
        ),
      );
    }

    return appBar;
  }
}

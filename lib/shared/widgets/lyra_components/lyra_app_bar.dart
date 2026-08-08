// ════════════════════════════════════════════════
// Project Lyra — LyraAppBar
// ════════════════════════════════════════════════

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Premium app bar with blur effect.
class LyraAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LyraAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.showBackButton = true,
    this.blur = false,
    this.centerTitle = true,
    this.height = 56,
    this.bottom,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool blur;
  final bool centerTitle;
  final double height;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: titleWidget ??
          (title != null
              ? Text(title!, style: Theme.of(context).textTheme.titleLarge)
              : null),
      leading: leading,
      actions: actions,
      automaticallyImplyLeading: showBackButton,
      centerTitle: centerTitle,
      elevation: 0,
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

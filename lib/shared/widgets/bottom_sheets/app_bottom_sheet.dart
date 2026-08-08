// ════════════════════════════════════════════════
// Project Lyra — App Bottom Sheet
// ════════════════════════════════════════════════
//
// Premium bottom sheet with rounded corners,
// drag handle, and consistent styling.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Show a styled bottom sheet.
Future<T?> showLyraBottomSheet<T>(
  BuildContext context, {
  required Widget child,
  String? title,
  bool isScrollControlled = true,
  bool showDragHandle = true,
  double? maxHeight,
}) {
  final lyra = context.lyra;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(lyra.radiusXLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          if (showDragHandle) ...[
            SizedBox(height: lyra.spacingSm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],

          // Title
          if (title != null) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                lyra.spacingLg,
                lyra.spacingMd,
                lyra.spacingLg,
                lyra.spacingSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(color: lyra.dividerColor, height: 1),
          ],

          // Content
          Flexible(child: child),
        ],
      ),
    ),
  );
}

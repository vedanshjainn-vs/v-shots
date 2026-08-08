// ════════════════════════════════════════════════
// Project Lyra — App Dialog
// ════════════════════════════════════════════════
//
// Premium dialog with rounded corners,
// glass effect, and consistent styling.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Show a styled dialog.
Future<T?> showLyraDialog<T>(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmText,
  String? cancelText,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
  IconData? icon,
  Color? iconColor,
  bool barrierDismissible = true,
}) {
  final colors = context.colors;
  final lyra = context.lyra;

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => AlertDialog(
      icon: icon != null
          ? Icon(icon, color: iconColor ?? colors.primary, size: 40)
          : null,
      title: Text(title, textAlign: TextAlign.center),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.onSurfaceVariant),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (cancelText != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onCancel?.call();
            },
            child: Text(cancelText),
          ),
        if (confirmText != null)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm?.call();
            },
            child: Text(confirmText),
          ),
      ],
    ),
  );
}

/// Confirmation dialog shortcut.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  IconData? icon,
}) async {
  final result = await showLyraDialog<bool>(
    context,
    title: title,
    message: message,
    confirmText: confirmText,
    cancelText: cancelText,
    icon: icon,
    onConfirm: () {},
  );
  return result ?? false;
}

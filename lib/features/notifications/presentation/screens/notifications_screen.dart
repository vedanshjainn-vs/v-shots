// ════════════════════════════════════════════════
// Project Lyra — Notifications Screen
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/extensions/color_extension.dart';
import '../../../../config/theme/extensions/theme_extension.dart';
import '../../../../config/theme/typography/app_typography.dart';
import '../../domain/entities/notification_entities.dart';

/// Notifications screen.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('Mark all read', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (_, i) {
          final isRead = i > 3;
          return Dismissible(
            key: Key('notif_$i'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: lyra.spacingMd),
              color: colors.error,
              child: Icon(Icons.delete, color: colors.onError),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isRead ? colors.surfaceContainerHighest : colors.primaryContainer,
                child: Icon(
                  i % 3 == 0 ? Icons.music_note : i % 3 == 1 ? Icons.album : Icons.person,
                  color: isRead ? colors.onSurfaceVariant : colors.primary,
                ),
              ),
              title: Text(
                'Notification Title ${i + 1}',
                style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.w600),
              ),
              subtitle: Text(
                'Description of the notification',
                style: AppTypography.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              trailing: Text(
                '${i + 1}h ago',
                style: AppTypography.caption.copyWith(color: colors.onSurfaceVariant),
              ),
              tileColor: isRead ? null : colors.primaryContainer.withValues(alpha: 0.1),
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}

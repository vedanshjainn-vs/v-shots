// ════════════════════════════════════════════════
// Project Lyra — History Screen
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/extensions/color_extension.dart';
import '../../../../config/theme/extensions/theme_extension.dart';
import '../../../../config/theme/typography/app_typography.dart';
import '../../../../shared/widgets/feedback/lyra_empty_state.dart';

/// History screen — listening history.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listening History'),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('Clear', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (_, i) {
          final hour = i + 1;
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(lyra.radiusSm),
              child: Container(
                width: 48,
                height: 48,
                color: colors.surfaceContainerHighest,
                child: Icon(Icons.music_note, color: colors.onSurfaceVariant),
              ),
            ),
            title: Text('Track ${i + 1}'),
            subtitle: Text('Artist ${i + 1}'),
            trailing: Text(
              '${hour}h ago',
              style: AppTypography.caption.copyWith(color: colors.onSurfaceVariant),
            ),
            onTap: () {},
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Project Lyra — Downloads Screen
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/extensions/color_extension.dart';
import '../../../../config/theme/extensions/theme_extension.dart';
import '../../../../config/theme/typography/app_typography.dart';
import '../../../../shared/widgets/feedback/lyra_empty_state.dart';
import '../../domain/entities/download_entities.dart';

/// Downloads screen — shows downloaded tracks.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 0,
        itemBuilder: (_, i) => const SizedBox(),
        // TODO(team): Connect to download repository.
        // When empty:
        // LyraEmptyState(
        //   icon: Icons.download_done_rounded,
        //   title: 'No Downloads',
        //   message: 'Downloaded music will appear here for offline listening.',
        // ),
      ),
    );
  }
}

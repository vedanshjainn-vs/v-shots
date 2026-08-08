// ════════════════════════════════════════════════
// Project Lyra — Playlist Screen
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/extensions/color_extension.dart';
import '../../../../config/theme/extensions/theme_extension.dart';
import '../../../../config/theme/typography/app_typography.dart';
import '../../../../shared/widgets/lyra_components/lyra_track_tile.dart';

/// Playlist detail screen.
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({required this.playlistId, super.key});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Playlist header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.primary.withValues(alpha: 0.4),
                      colors.surface,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(lyra.radiusLarge),
                        ),
                        child: Icon(Icons.playlist_play, size: 80, color: colors.onSurfaceVariant),
                      ),
                      SizedBox(height: lyra.spacingMd),
                      Text('Playlist Name', style: AppTypography.headlineMedium),
                      SizedBox(height: lyra.spacingXs),
                      Text(
                        'Created by User • 25 songs',
                        style: AppTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.share), onPressed: () {}),
              IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
            ],
          ),

          // Action buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd, vertical: lyra.spacingSm),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play'),
                    ),
                  ),
                  SizedBox(width: lyra.spacingSm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('Shuffle'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Track list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => LyraTrackTile(
                title: 'Track ${i + 1}',
                artist: 'Artist ${i + 1}',
                duration: Duration(minutes: 3, seconds: 30 + i),
                isPlaying: i == 0,
                onTap: () {},
                onMoreTap: () {},
              ),
              childCount: 25,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

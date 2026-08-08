// ════════════════════════════════════════════════
// Project Lyra — Album Screen
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/extensions/color_extension.dart';
import '../../../../config/theme/extensions/theme_extension.dart';
import '../../../../config/theme/typography/app_typography.dart';
import '../../../../shared/widgets/lyra_components/lyra_track_tile.dart';

/// Album detail screen.
class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({required this.albumId, super.key});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Album header
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.primary.withValues(alpha: 0.3),
                      colors.surface,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(lyra.radiusLarge),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(Icons.album, size: 80, color: colors.onSurfaceVariant),
                      ),
                      SizedBox(height: lyra.spacingMd),
                      Text('Album Name', style: AppTypography.headlineMedium),
                      SizedBox(height: lyra.spacingXs),
                      GestureDetector(
                        onTap: () {},
                        child: Text(
                          'Artist Name',
                          style: AppTypography.bodyLarge.copyWith(color: colors.primary),
                        ),
                      ),
                      SizedBox(height: lyra.spacingXs),
                      Text(
                        '2024 • 12 songs • 45 min',
                        style: AppTypography.bodySmall.copyWith(color: colors.onSurfaceVariant),
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite_border, color: colors.onSurfaceVariant, size: 20),
                  ),
                  SizedBox(width: lyra.spacingMd),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play'),
                    ),
                  ),
                  SizedBox(width: lyra.spacingSm),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shuffle, color: colors.onSurfaceVariant, size: 20),
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
                artist: 'Artist Name',
                duration: Duration(minutes: 3, seconds: 30 + i),
                showIndex: true,
                index: i,
                onTap: () {},
                onMoreTap: () {},
              ),
              childCount: 12,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

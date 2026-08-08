// ════════════════════════════════════════════════
// Project Lyra — Artist Screen
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/extensions/color_extension.dart';
import '../../../../config/theme/extensions/theme_extension.dart';
import '../../../../config/theme/typography/app_typography.dart';
import '../../../../shared/widgets/lyra_components/lyra_card.dart';
import '../../../../shared/widgets/lyra_components/lyra_section_header.dart';
import '../../../../shared/widgets/lyra_components/lyra_track_tile.dart';

/// Artist detail screen.
class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({required this.artistId, super.key});

  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Artist header
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
                      colors.primary.withValues(alpha: 0.3),
                      colors.surface,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: colors.surfaceContainerHighest,
                        child: Icon(Icons.person, size: 60, color: colors.onSurfaceVariant),
                      ),
                      SizedBox(height: lyra.spacingMd),
                      Text('Artist Name', style: AppTypography.headlineLarge),
                      SizedBox(height: lyra.spacingXs),
                      Text(
                        '1.2M monthly listeners',
                        style: AppTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant),
                      ),
                      SizedBox(height: lyra.spacingMd),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () {},
                            child: const Text('Following'),
                          ),
                          SizedBox(width: lyra.spacingSm),
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Popular tracks
          SliverToBoxAdapter(
            child: LyraSectionHeader(title: 'Popular'),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => LyraTrackTile(
                title: 'Popular Track ${i + 1}',
                artist: 'Artist Name',
                duration: Duration(minutes: 3, seconds: 30 + i),
                showIndex: true,
                index: i,
                onTap: () {},
                onMoreTap: () {},
              ),
              childCount: 5,
            ),
          ),

          // Albums
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LyraSectionHeader(title: 'Albums', onViewAll: () {}),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
                    itemCount: 5,
                    itemBuilder: (_, i) => Padding(
                      padding: EdgeInsets.only(right: lyra.spacingSm),
                      child: LyraCard(
                        title: 'Album ${i + 1}',
                        imageUrl: 'https://picsum.photos/200?random=${i + 50}',
                        subtitle: '2024',
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
                SizedBox(height: lyra.spacingLg),
              ],
            ),
          ),

          // Similar artists
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LyraSectionHeader(title: 'Fans Also Like'),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
                    itemCount: 5,
                    itemBuilder: (_, i) => Padding(
                      padding: EdgeInsets.only(right: lyra.spacingMd),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: colors.surfaceContainerHighest,
                            child: Icon(Icons.person, size: 40, color: colors.onSurfaceVariant),
                          ),
                          SizedBox(height: lyra.spacingSm),
                          Text('Artist ${i + 1}', style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

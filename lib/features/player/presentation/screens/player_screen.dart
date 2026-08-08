// ════════════════════════════════════════════════
// Project Lyra — Full Player Screen
// ════════════════════════════════════════════════

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/extensions/color_extension.dart';
import '../../../../config/theme/extensions/theme_extension.dart';
import '../../../../config/theme/typography/app_typography.dart';
import '../../../../core/utils/extensions/num_extensions.dart';

/// Full-screen player — Apple Music quality.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Column(
                      children: [
                        Text('PLAYING FROM', style: AppTypography.caption.copyWith(color: colors.onSurfaceVariant)),
                        Text('Playlist', style: AppTypography.labelMedium),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Artwork
              Padding(
                padding: EdgeInsets.symmetric(horizontal: lyra.spacingXxl),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(lyra.radiusXLarge),
                      color: colors.surfaceContainerHighest,
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.3),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(lyra.radiusXLarge),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                        child: Center(
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 80,
                            color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Track info
              Padding(
                padding: EdgeInsets.symmetric(horizontal: lyra.spacingLg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Track Title',
                            style: AppTypography.headlineSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: lyra.spacingXxs),
                          Text(
                            'Artist Name',
                            style: AppTypography.bodyLarge.copyWith(color: colors.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.favorite_border_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              SizedBox(height: lyra.spacingLg),

              // Progress bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: lyra.spacingLg),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: colors.primary,
                        inactiveTrackColor: colors.surfaceContainerHighest,
                        thumbColor: colors.primary,
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: 0.3,
                        onChanged: (v) {},
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: lyra.spacingSm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1:23', style: AppTypography.caption.copyWith(color: colors.onSurfaceVariant)),
                          Text('3:45', style: AppTypography.caption.copyWith(color: colors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: lyra.spacingMd),

              // Playback controls
              Padding(
                padding: EdgeInsets.symmetric(horizontal: lyra.spacingLg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shuffle_rounded, size: 24),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, size: 36),
                      onPressed: () {},
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.onSurface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 36,
                        color: colors.surface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 36),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.repeat_rounded, size: 24),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              SizedBox(height: lyra.spacingLg),

              // Bottom actions
              Padding(
                padding: EdgeInsets.symmetric(horizontal: lyra.spacingLg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.lyrics_outlined, color: colors.onSurfaceVariant),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(Icons.queue_music_rounded, color: colors.onSurfaceVariant),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(Icons.airplay_rounded, color: colors.onSurfaceVariant),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(Icons.share_outlined, color: colors.onSurfaceVariant),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              SizedBox(height: lyra.spacingLg),
            ],
          ),
        ),
      ),
    );
  }
}

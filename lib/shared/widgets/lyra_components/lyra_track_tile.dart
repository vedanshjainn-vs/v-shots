// ════════════════════════════════════════════════
// Project Lyra — LyraTrackTile
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';
import '../../../config/theme/typography/app_typography.dart';
import '../../../core/utils/extensions/num_extensions.dart';

/// Premium track list tile with artwork, metadata, and actions.
class LyraTrackTile extends StatelessWidget {
  const LyraTrackTile({
    required this.title,
    required this.artist,
    super.key,
    this.imageUrl,
    this.duration,
    this.onTap,
    this.onMoreTap,
    this.isPlaying = false,
    this.isLiked = false,
    this.onLikeTap,
    this.showIndex = false,
    this.index,
    this.trailing,
  });

  final String title;
  final String artist;
  final String? imageUrl;
  final Duration? duration;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;
  final bool isPlaying;
  final bool isLiked;
  final VoidCallback? onLikeTap;
  final bool showIndex;
  final int? index;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: lyra.spacingMd,
          vertical: lyra.spacingSm,
        ),
        child: Row(
          children: [
            // Index or artwork
            if (showIndex && index != null)
              SizedBox(
                width: 24,
                child: Text(
                  '${index! + 1}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(lyra.radiusSm),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: colors.surfaceContainerHighest,
                    child: Icon(Icons.music_note, color: colors.onSurfaceVariant, size: 20),
                  ),
                ),
              ),
            SizedBox(width: lyra.spacingMd),

            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      color: isPlaying ? colors.primary : colors.onSurface,
                      fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: lyra.spacingXxs),
                  Text(
                    artist,
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Trailing actions
            if (trailing != null)
              trailing!
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (duration != null)
                    Padding(
                      padding: EdgeInsets.only(right: lyra.spacingSm),
                      child: Text(
                        duration!.inSeconds.toDurationString,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (onLikeTap != null)
                    GestureDetector(
                      onTap: onLikeTap,
                      child: Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? colors.primary : colors.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  if (onMoreTap != null)
                    GestureDetector(
                      onTap: onMoreTap,
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: colors.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

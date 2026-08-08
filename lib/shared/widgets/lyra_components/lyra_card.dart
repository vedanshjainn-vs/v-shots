// ════════════════════════════════════════════════
// Project Lyra — LyraCard
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Premium media card for albums, playlists, artists.
class LyraCard extends StatelessWidget {
  const LyraCard({
    required this.title,
    required this.imageUrl,
    super.key,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.width = 160,
    this.showPlayButton = false,
    this.onPlayTap,
    this.isCircular = false,
    this.badge,
  });

  final String title;
  final String imageUrl;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double width;
  final bool showPlayButton;
  final VoidCallback? onPlayTap;
  final bool isCircular;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;
    final imageSize = isCircular ? width : width;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork
            Stack(
              children: [
                ClipRRect(
                  borderRadius: isCircular
                      ? BorderRadius.circular(lyra.radiusCircular)
                      : BorderRadius.circular(lyra.radiusLarge),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Shimmer.fromColors(
                      baseColor: lyra.shimmerBase,
                      highlightColor: lyra.shimmerHighlight,
                      child: Container(
                        width: imageSize,
                        height: imageSize,
                        color: lyra.shimmerBase,
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: imageSize,
                      height: imageSize,
                      color: colors.surfaceContainerHighest,
                      child: Icon(
                        Icons.music_note_rounded,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                        size: imageSize * 0.3,
                      ),
                    ),
                  ),
                ),
                if (showPlayButton)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: GestureDetector(
                      onTap: onPlayTap,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: lyra.shadowColor,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: colors.onPrimary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                if (badge != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: badge!,
                  ),
              ],
            ),
            SizedBox(height: lyra.spacingSm),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              SizedBox(height: lyra.spacingXxs),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Project Lyra — Media Card
// ════════════════════════════════════════════════
//
// Standard card for albums, playlists, artists,
// podcasts. Large rounded artwork with metadata.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';
import '../../../config/theme/typography/app_typography.dart';
import '../images/artwork_image.dart';

/// A large media card for browsable content.
///
/// Shows artwork, title, subtitle, and optional badge.
/// Used in horizontal carousels and grids.
class MediaCard extends StatelessWidget {
  const MediaCard({
    required this.title,
    required this.imageUrl,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.width = 160,
    this.showPlayButton = false,
    this.onPlayTap,
    this.badge,
    this.isCircular = false,
    super.key,
  });

  final String title;
  final String imageUrl;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double width;
  final bool showPlayButton;
  final VoidCallback? onPlayTap;
  final Widget? badge;
  final bool isCircular;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;
    final imageHeight = isCircular ? width : width;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Artwork ───────────────────────
            Stack(
              children: [
                ArtworkImage(
                  imageUrl: imageUrl,
                  width: width,
                  height: imageHeight,
                  borderRadius: isCircular
                      ? BorderRadius.circular(lyra.radiusCircular)
                      : BorderRadius.circular(lyra.radiusLarge),
                ),

                // Play button overlay.
                if (showPlayButton)
                  Positioned(
                    right: lyra.spacingSm,
                    bottom: lyra.spacingSm,
                    child: _PlayButton(onTap: onPlayTap),
                  ),

                // Badge overlay.
                if (badge != null)
                  Positioned(
                    top: lyra.spacingSm,
                    left: lyra.spacingSm,
                    child: badge!,
                  ),
              ],
            ),

            SizedBox(height: lyra.spacingSm),

            // ── Title ────────────────────────
            Text(
              title,
              style: AppTypography.titleSmall.copyWith(
                color: colors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Subtitle ─────────────────────
            if (subtitle != null) ...[
              SizedBox(height: lyra.spacingXxs),
              Text(
                subtitle!,
                style: AppTypography.bodySmall.copyWith(
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

/// Circular play button overlay for artwork.
class _PlayButton extends StatelessWidget {
  const _PlayButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
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
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: colors.onPrimary,
          size: 22,
        ),
      ),
    );
  }
}

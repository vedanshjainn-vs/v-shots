// ════════════════════════════════════════════════
// Project Lyra — Artwork Image
// ════════════════════════════════════════════════
//
// Network image for album art, artist photos,
// playlist covers. Handles loading, error states,
// and placeholder images.
// ════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../config/constants/asset_constants.dart';
import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// A network image optimized for music artwork.
///
/// Features:
/// - Cached with [CachedNetworkImage]
/// - Shimmer loading animation
/// - Graceful error placeholder
/// - Configurable border radius
class ArtworkImage extends StatelessWidget {
  const ArtworkImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholderAsset,
    this.heroTag,
    super.key,
  });

  final String imageUrl;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final String? placeholderAsset;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;
    final effectiveRadius = borderRadius ??
        BorderRadius.circular(lyra.radiusLarge);

    final image = ClipRRect(
      borderRadius: effectiveRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _ShimmerPlaceholder(
          width: width,
          height: height,
          borderRadius: effectiveRadius,
        ),
        errorWidget: (context, url, error) => _ErrorPlaceholder(
          width: width,
          height: height,
          borderRadius: effectiveRadius,
          asset: placeholderAsset ?? AssetConstants.placeholderAlbum,
          color: colors.surfaceContainerHighest,
        ),
      ),
    );

    // Optional hero animation tag.
    if (heroTag != null) {
      return Hero(tag: heroTag!, child: image);
    }

    return image;
  }
}

/// Shimmer loading state for artwork.
class _ShimmerPlaceholder extends StatelessWidget {
  const _ShimmerPlaceholder({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;

    return Shimmer.fromColors(
      baseColor: lyra.shimmerBase,
      highlightColor: lyra.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: lyra.shimmerBase,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// Error / fallback placeholder for artwork.
class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.asset,
    required this.color,
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;
  final String asset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: colors.onSurfaceVariant.withValues(alpha: 0.4),
          size: width * 0.3,
        ),
      ),
    );
  }
}

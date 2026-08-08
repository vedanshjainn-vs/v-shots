// ════════════════════════════════════════════════
// Project Lyra — Cached Image
// ════════════════════════════════════════════════
//
// General-purpose cached network image.
// For avatars, backgrounds, and non-artwork images.
// ════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';

/// Cached network image with placeholder and error handling.
class LyraCachedImage extends StatelessWidget {
  const LyraCachedImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    super.key,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: colors.surfaceContainerHighest,
          ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: colors.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_rounded,
          color: colors.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

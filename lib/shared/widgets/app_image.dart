// ════════════════════════════════════════════════
// V Shots — Cached network image widget
// ════════════════════════════════════════════════
//
// WHY THIS EXISTS (per user-approved refinement list, Section B #1):
// Every artwork image in the app (Home cards, Search results, For You
// feed cards, Player screen, mini-player) previously used plain
// `Image.network(url)`, which has NO disk or persistent memory cache
// in Flutter — the same artwork gets re-downloaded from scratch every
// time a widget rebuilds or a list item scrolls back into view. This
// was flagged as very likely the single biggest cause of the app
// "feeling slow" on a real device/network.
//
// This widget is a drop-in replacement using `cached_network_image`
// (disk + memory cache via flutter_cache_manager under the hood) with
// the same call shape as the old `Image.network(..., errorBuilder: ...)`
// calls it replaces, so swapping call sites is mechanical, not a
// rewrite of surrounding layout code.
// ════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Drop-in cached replacement for `Image.network`. Pass the same
/// [width]/[height]/[fit] you would to Image.network; [placeholderColor]
/// controls the shimmer-less loading tint shown while the image loads
/// (defaults to the app's dark surface color so it blends in rather
/// than flashing white).
class AppImage extends StatelessWidget {
  const AppImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderColor = const Color(0xFF1A1A2E),
    this.errorIcon = Icons.music_note,
    this.errorIconColor = const Color(0xFFFF4D6A),
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color placeholderColor;
  final IconData errorIcon;
  final Color errorIconColor;

  @override
  Widget build(BuildContext context) {
    Widget image;

    if (url == null || url!.isEmpty) {
      image = _fallback();
    } else {
      image = CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: fit,
        // Fade-in avoids a jarring pop once the cached/network image
        // resolves — a small but real "feels premium" touch that was
        // previously entirely absent (Image.network has no built-in
        // fade transition).
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: placeholderColor,
        ),
        errorWidget: (context, url, error) => _fallback(),
        // Memory-cache at roughly display resolution (not the full
        // decoded source size) — real, measurable memory savings for
        // long scrolling lists of thumbnails, since we're not holding
        // full-resolution decoded bitmaps for images shown at 150x150.
        memCacheWidth: width != null ? (width! * 2).round() : null,
        memCacheHeight: height != null ? (height! * 2).round() : null,
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _fallback() => Container(
        width: width,
        height: height,
        color: placeholderColor,
        child: Icon(errorIcon,
            color: errorIconColor, size: (width ?? height ?? 48) * 0.4),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Playback Router (multi-provider URL resolution)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

import '../../shared/utils/youtube_url.dart';
import '../providers/jiosaavn_web_provider.dart';

enum PlaybackSource { youtube, jiosaavn }

class PlaybackTarget {
  const PlaybackTarget({
    required this.source,
    required this.url,
    this.fallbackSource,
  });
  final PlaybackSource source;
  final String url;
  final PlaybackSource? fallbackSource;
}

class PlaybackRouter {
  PlaybackRouter._();
  static final PlaybackRouter instance = PlaybackRouter._();

  Future<PlaybackTarget> resolvePlayback(Map<String, dynamic> track) async {
    // 1. Explicit JioSaavn permalink
    final jiosaavnUrl = track['jiosaavnUrl'] as String?;
    if (jiosaavnUrl != null && jiosaavnUrl.isNotEmpty) {
      if (JioSaavnWebProvider.isValidJioSaavnUrl(jiosaavnUrl)) {
        return PlaybackTarget(
          source: PlaybackSource.jiosaavn,
          url: jiosaavnUrl,
          fallbackSource: PlaybackSource.youtube,
        );
      }
    }

    // 2. Explicit playback source override
    final sourceOverride = (track['playbackSource'] as String?)?.toLowerCase();
    if (sourceOverride == 'jiosaavn') {
      return _resolveJioSaavn(track);
    }

    // 3. Pre-resolved URL
    final preResolved = track['url'] as String?;
    if (preResolved != null && preResolved.isNotEmpty) {
      final lower = preResolved.toLowerCase();
      if (lower.contains('jiosaavn.com') || lower.contains('saavn.com')) {
        return PlaybackTarget(
          source: PlaybackSource.jiosaavn,
          url: preResolved,
          fallbackSource: PlaybackSource.youtube,
        );
      }
    }

    // 4. Default: YouTube
    return _resolveYouTube(track);
  }

  PlaybackTarget _resolveYouTube(Map<String, dynamic> track) {
    final id = track['id'] as String? ?? '';
    if (id.isEmpty) {
      final fallbackUrl = track['url'] as String?;
      if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
        return PlaybackTarget(source: PlaybackSource.youtube, url: fallbackUrl);
      }
      return PlaybackTarget(
        source: PlaybackSource.youtube,
        url: 'https://www.youtube.com/',
      );
    }
    return PlaybackTarget(
      source: PlaybackSource.youtube,
      url: youtubeWatchUrl(id),
    );
  }

  Future<PlaybackTarget> _resolveJioSaavn(Map<String, dynamic> track) async {
    final title = track['title'] as String? ?? '';
    final artist = track['artist'] as String? ?? '';
    try {
      final url = await JioSaavnWebProvider.instance.resolveWebUrl(
        title: title,
        artist: artist,
      );
      if (url != null && url.isNotEmpty) {
        return PlaybackTarget(
          source: PlaybackSource.jiosaavn,
          url: url,
          fallbackSource: PlaybackSource.youtube,
        );
      }
    } catch (e) {
      debugPrint('[PlaybackRouter] JioSaavn failed: $e');
    }
    return _resolveYouTube(track);
  }
}

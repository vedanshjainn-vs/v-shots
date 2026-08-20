// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Playback Router
// ═════════════════════════════════════════════════════════════════════════════
//
// Routes song playback to the appropriate web player:
// - YouTube songs → YouTube webpage
// - JioSaavn songs → JioSaavn webpage
//
// Uses the existing VShotsBrowserSession for all playback.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

import '../providers/jiosaavn_web_provider.dart';
import '../../shared/utils/youtube_url.dart';

/// Playback source types
enum PlaybackSource {
  youtube,
  jiosaavn,
  unknown,
}

/// Resolved playback target
class PlaybackTarget {
  const PlaybackTarget({
    required this.source,
    required this.url,
    this.title,
    this.artist,
  });

  final PlaybackSource source;
  final String url;
  final String? title;
  final String? artist;
}

/// Routes songs to the appropriate web player
class PlaybackRouter {
  PlaybackRouter._();
  static final PlaybackRouter instance = PlaybackRouter._();

  /// Resolve a track to a playback URL
  /// Returns the URL to open in the V Shots browser
  Future<PlaybackTarget> resolvePlayback(Map<String, dynamic> track) async {
    final title = (track['title'] as String?) ?? '';
    final artist = (track['artist'] as String?) ?? '';
    final trackId = (track['id'] as String?) ?? '';
    final source = (track['source'] as String?) ?? '';
    final provider = (track['provider'] as String?) ?? '';

    // Strategy 1: Check if track has explicit provider
    if (provider.toLowerCase().contains('jiosaavn') || 
        source.toLowerCase().contains('jiosaavn')) {
      return _resolveJioSaavn(track);
    }

    // Strategy 2: Check if track has YouTube ID
    if (trackId.isNotEmpty && _isYouTubeId(trackId)) {
      return PlaybackTarget(
        source: PlaybackSource.youtube,
        url: youtubeWatchUrl(trackId),
        title: title,
        artist: artist,
      );
    }

    // Strategy 3: Check if track has a direct URL
    final directUrl = track['url'] as String? ?? track['webUrl'] as String?;
    if (directUrl != null && directUrl.isNotEmpty) {
      if (directUrl.contains('youtube.com') || directUrl.contains('youtu.be')) {
        return PlaybackTarget(
          source: PlaybackSource.youtube,
          url: directUrl,
          title: title,
          artist: artist,
        );
      }
      if (directUrl.contains('jiosaavn.com') || directUrl.contains('saavn.com')) {
        return PlaybackTarget(
          source: PlaybackSource.jiosaavn,
          url: directUrl,
          title: title,
          artist: artist,
        );
      }
    }

    // Strategy 4: Default to YouTube search
    final searchQuery = Uri.encodeComponent('$title $artist official');
    return PlaybackTarget(
      source: PlaybackSource.youtube,
      url: 'https://www.youtube.com/results?search_query=$searchQuery',
      title: title,
      artist: artist,
    );
  }

  /// Resolve JioSaavn playback
  Future<PlaybackTarget> _resolveJioSaavn(Map<String, dynamic> track) async {
    final title = (track['title'] as String?) ?? '';
    final artist = (track['artist'] as String?) ?? '';

    // Try to resolve via JioSaavn provider
    final resolved = await JioSaavnWebPlaybackProvider.instance.resolveFromTrack(track);
    
    if (resolved != null) {
      return PlaybackTarget(
        source: PlaybackSource.jiosaavn,
        url: resolved.webUrl,
        title: resolved.title,
        artist: resolved.artist,
      );
    }

    // Fallback to search URL
    final searchQuery = Uri.encodeComponent('$title $artist');
    return PlaybackTarget(
      source: PlaybackSource.jiosaavn,
      url: 'https://www.jiosaavn.com/search/$searchQuery',
      title: title,
      artist: artist,
    );
  }

  /// Check if a string looks like a YouTube video ID
  bool _isYouTubeId(String id) {
    // YouTube IDs are 11 characters, alphanumeric + hyphens + underscores
    return RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id);
  }
}

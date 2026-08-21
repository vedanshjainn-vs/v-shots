// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Playback Router (deterministic multi-provider URL resolution)
// ═════════════════════════════════════════════════════════════════════════════
//
// AUTO:
//   1. JioSaavn enabled + exact permalink → JioSaavn
//   2. YouTube ID → YouTube
//   3. JioSaavn search fallback enabled → JioSaavn search
//   4. unavailable
// JIOSAAVN: permalink → search (if enabled) → unavailable
// YOUTUBE: valid ID/URL → else unavailable
//
// Fallback URLs are attached but NEVER used until the primary page fails.

import '../../shared/utils/youtube_url.dart';
import '../providers/jiosaavn_web_provider.dart';
import '../remote_config/remote_feature_flags.dart';

enum PlaybackSource { youtube, jiosaavn }

class PlaybackTarget {
  const PlaybackTarget({
    required this.source,
    required this.url,
    this.fallbackSource,
    this.fallbackUrl,
    this.available = true,
    this.unavailableReason,
  });

  factory PlaybackTarget.unavailable(String reason) => PlaybackTarget(
        source: PlaybackSource.youtube,
        url: '',
        available: false,
        unavailableReason: reason,
      );

  final PlaybackSource source;
  final String url;
  final PlaybackSource? fallbackSource;
  final String? fallbackUrl;
  final bool available;
  final String? unavailableReason;

  bool get isUnavailable => !available || url.isEmpty;
}

class PlaybackRouter {
  PlaybackRouter({PlaybackPolicy? policy}) : _policy = policy;
  PlaybackRouter._() : _policy = null;

  static final PlaybackRouter instance = PlaybackRouter._();

  final PlaybackPolicy? _policy;

  PlaybackPolicy get policy =>
      _policy ?? RemoteFeatureFlags.instance.playbackPolicy;

  Future<PlaybackTarget> resolvePlayback(Map<String, dynamic> track) async {
    final requested = _requestedSource(track);
    switch (requested) {
      case 'jiosaavn':
        return _resolveJioSaavn(track);
      case 'youtube':
        return _resolveYouTube(track);
      default:
        return _resolveAuto(track);
    }
  }

  /// Copy of [track] with `url` / `playbackSource` / fallback fields set.
  Future<Map<String, dynamic>> attachResolvedPlayback(
    Map<String, dynamic> track,
  ) async {
    final target = await resolvePlayback(track);
    final copy = Map<String, dynamic>.from(track);
    if (target.isUnavailable) {
      copy['playbackUnavailable'] = true;
      copy['unavailableReason'] =
          target.unavailableReason ?? 'This track is unavailable';
      return copy;
    }
    copy['playbackUnavailable'] = false;
    copy['url'] = target.url;
    copy['playbackSource'] = target.source.name;
    if (target.fallbackSource != null) {
      copy['fallbackSource'] = target.fallbackSource!.name;
    }
    if (target.fallbackUrl != null && target.fallbackUrl!.isNotEmpty) {
      copy['fallbackUrl'] = target.fallbackUrl;
    }
    return copy;
  }

  Future<List<Map<String, dynamic>>> resolveQueue(
    List<Map<String, dynamic>> queue,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (final track in queue) {
      out.add(await attachResolvedPlayback(track));
    }
    return out;
  }

  PlaybackTarget _resolveAuto(Map<String, dynamic> track) {
    final permalink = _permalinkOf(track);
    if (policy.jiosaavnWebPlayback && permalink != null) {
      return _jiosaavnTarget(track, permalink);
    }
    final youtube = _resolveYouTube(track);
    if (!youtube.isUnavailable) return youtube;
    if (policy.jiosaavnWebPlayback && policy.jiosaavnSearchFallback) {
      final search = _searchUrlOf(track);
      if (search != null) return _jiosaavnTarget(track, search);
    }
    return PlaybackTarget.unavailable(
      youtube.unavailableReason ?? 'No playable source for this track',
    );
  }

  PlaybackTarget _resolveJioSaavn(Map<String, dynamic> track) {
    if (!policy.jiosaavnWebPlayback) {
      // Master switch off: do not offer JioSaavn. YouTube only if the
      // requested source is not exclusively JioSaavn — callers that asked
      // for JioSaavn get a real error rather than a silent YouTube play.
      return PlaybackTarget.unavailable('JioSaavn playback is turned off');
    }
    final permalink = _permalinkOf(track);
    if (permalink != null) return _jiosaavnTarget(track, permalink);
    if (policy.jiosaavnSearchFallback) {
      final search = _searchUrlOf(track);
      if (search != null) return _jiosaavnTarget(track, search);
    }
    return PlaybackTarget.unavailable(
      policy.jiosaavnSearchFallback
          ? 'No JioSaavn permalink or search query'
          : 'Exact JioSaavn URL required (search fallback is off)',
    );
  }

  PlaybackTarget _resolveYouTube(Map<String, dynamic> track) {
    final id = youtubeIdOf(track);
    if (id == null || id.isEmpty) {
      return PlaybackTarget.unavailable('No YouTube video id');
    }
    return PlaybackTarget(
      source: PlaybackSource.youtube,
      url: youtubeWatchUrl(id),
    );
  }

  PlaybackTarget _jiosaavnTarget(Map<String, dynamic> track, String url) {
    final ytId = youtubeIdOf(track);
    final fallback = _fallbackSourceOf(track);
    String? fallbackUrl;
    PlaybackSource? fallbackSource;
    if (fallback == PlaybackSource.youtube && ytId != null) {
      fallbackSource = PlaybackSource.youtube;
      fallbackUrl = youtubeWatchUrl(ytId);
    }
    return PlaybackTarget(
      source: PlaybackSource.jiosaavn,
      url: url,
      fallbackSource: fallbackSource,
      fallbackUrl: fallbackUrl,
    );
  }

  static String _requestedSource(Map<String, dynamic> track) {
    final raw = '${track['playbackSource'] ?? track['provider'] ?? ''}'
        .trim()
        .toLowerCase();
    if (raw.contains('jiosaavn')) return 'jiosaavn';
    if (raw.contains('youtube')) return 'youtube';
    if (raw == 'auto') return 'auto';
    return 'auto';
  }

  static String? _permalinkOf(Map<String, dynamic> track) {
    for (final key in ['jiosaavnUrl', 'jiosaavn_url']) {
      final value = track[key];
      if (value is String && JioSaavnWebProvider.isValidPermalink(value)) {
        return value.trim();
      }
    }
    final url = track['url'];
    if (url is String && JioSaavnWebProvider.isValidPermalink(url)) {
      return url.trim();
    }
    return null;
  }

  static String? _searchUrlOf(Map<String, dynamic> track) {
    final url = track['url'];
    if (url is String && JioSaavnWebProvider.isValidSearchUrl(url)) {
      return url.trim();
    }
    final built = JioSaavnWebProvider.buildSearchUrl(
      title: '${track['title'] ?? ''}',
      artist: '${track['artist'] ?? ''}',
    );
    return built.isEmpty ? null : built;
  }

  static PlaybackSource? _fallbackSourceOf(Map<String, dynamic> track) {
    final raw = '${track['fallbackSource'] ?? ''}'.trim().toLowerCase();
    if (raw.isEmpty || raw == 'none') return null;
    if (raw.contains('jiosaavn')) return PlaybackSource.jiosaavn;
    if (raw.contains('youtube')) return PlaybackSource.youtube;
    return null;
  }
}

/// YouTube video id from explicit `youtubeId`, a bare 11-char `id`, or URL.
String? youtubeIdOf(Map<String, dynamic> track) {
  final explicit = track['youtubeId'] ?? track['youtube_video_id'];
  if (explicit is String && explicit.trim().isNotEmpty) {
    return extractYoutubeVideoId(explicit.trim());
  }
  final id = track['id'];
  if (id is String && id.trim().isNotEmpty) {
    final extracted = extractYoutubeVideoId(id.trim());
    if (extracted != null) return extracted;
  }
  final url = track['url'];
  if (url is String && url.trim().isNotEmpty) {
    return extractYoutubeVideoId(url.trim());
  }
  return null;
}

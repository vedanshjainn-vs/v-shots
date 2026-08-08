// ════════════════════════════════════════════════
// V Shots — YouTube Music Client
// ════════════════════════════════════════════════

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../logging/app_logger.dart';

/// Client for YouTube Music API.
class YouTubeMusicClient {
  YouTubeMusicClient({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;
  late YoutubeExplode _yt;

  /// Initialize the client.
  Future<void> initialize() async {
    _yt = YoutubeExplode();
    _logger.i('YouTubeMusicClient: Initialized');
  }

  /// Dispose resources.
  void dispose() {
    _yt.close();
  }

  // ═══════════════════════════════════════════════
  // SEARCH
  // ═══════════════════════════════════════════════

  /// Search for videos/tracks on YouTube.
  Future<List<Video>> search(String query, {int limit = 20}) async {
    try {
      _logger.d('YouTubeMusicClient: Searching for "$query"');
      final searchList = await _yt.search.search(query);
      final results = searchList.whereType<Video>().take(limit).toList();
      _logger.d('YouTubeMusicClient: Found ${results.length} results');
      return results;
    } catch (e, st) {
      _logger.e('YouTubeMusicClient: Search failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get search suggestions.
  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      final suggestions = await _yt.search.getQuerySuggestions(query);
      return suggestions;
    } catch (e) {
      _logger.w('YouTubeMusicClient: Suggestions failed');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // VIDEO METADATA
  // ═══════════════════════════════════════════════

  /// Get video details by ID.
  Future<Video?> getVideo(String videoId) async {
    try {
      _logger.d('YouTubeMusicClient: Getting video $videoId');
      final video = await _yt.videos.get(videoId);
      return video;
    } catch (e, st) {
      _logger.e('YouTubeMusicClient: getVideo failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Get multiple videos by IDs.
  Future<List<Video>> getVideos(List<String> videoIds) async {
    try {
      final videos = <Video>[];
      for (final id in videoIds) {
        final video = await _yt.videos.get(id);
        videos.add(video);
      }
      return videos;
    } catch (e, st) {
      _logger.e('YouTubeMusicClient: getVideos failed', error: e, stackTrace: st);
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // PLAYLIST
  // ═══════════════════════════════════════════════

  /// Get playlist videos.
  Future<List<Video>> getPlaylistVideos(String playlistId, {int limit = 50}) async {
    try {
      _logger.d('YouTubeMusicClient: Getting playlist $playlistId');
      final videos = <Video>[];

      await for (final video in _yt.playlists.getVideos(playlistId).take(limit)) {
        videos.add(video);
      }

      return videos;
    } catch (e, st) {
      _logger.e('YouTubeMusicClient: getPlaylistVideos failed', error: e, stackTrace: st);
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // STREAM
  // ═══════════════════════════════════════════════

  /// Get audio stream URL for a video.
  Future<StreamInfoWrapper?> getAudioStream(String videoId) async {
    try {
      _logger.d('YouTubeMusicClient: Getting stream for $videoId');

      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // Get audio-only streams, sorted by bitrate (highest first).
      final audioStreams = manifest.audioOnly.sortByBitrate();

      if (audioStreams.isEmpty) {
        _logger.w('YouTubeMusicClient: No audio streams found');
        return null;
      }

      // Prefer high quality audio.
      final stream = audioStreams.last;

      return StreamInfoWrapper(
        url: stream.url.toString(),
        bitrate: stream.bitrate.bitsPerSecond,
        codec: stream.audioCodec,
        container: stream.container.name,
        size: stream.size.totalBytes,
      );
    } catch (e, st) {
      _logger.e('YouTubeMusicClient: getAudioStream failed', error: e, stackTrace: st);
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // CHANNEL / ARTIST
  // ═══════════════════════════════════════════════

  /// Get channel details.
  Future<Channel?> getChannel(String channelId) async {
    try {
      _logger.d('YouTubeMusicClient: Getting channel $channelId');
      final channel = await _yt.channels.get(channelId);
      return channel;
    } catch (e, st) {
      _logger.e('YouTubeMusicClient: getChannel failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Get channel videos.
  Future<List<Video>> getChannelVideos(String channelId, {int limit = 20}) async {
    try {
      final videos = <Video>[];
      await for (final video in _yt.channels.getUploads(channelId).take(limit)) {
        videos.add(video);
      }
      return videos;
    } catch (e, st) {
      _logger.e('YouTubeMusicClient: getChannelVideos failed', error: e, stackTrace: st);
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // RELATED
  // ═══════════════════════════════════════════════

  /// Get related/recommended videos.
  Future<List<Video>> getRelatedVideos(String videoId, {int limit = 20}) async {
    try {
      _logger.d('YouTubeMusicClient: Getting related for $videoId');
      final related = await _yt.videos.getRelatedVideos(videoId);
      if (related == null) return [];
      return related.take(limit).toList();
    } catch (e, st) {
      _logger.e('YouTubeMusicClient: getRelatedVideos failed', error: e, stackTrace: st);
      return [];
    }
  }
}

/// Wrapper for stream information.
class StreamInfoWrapper {
  const StreamInfoWrapper({
    required this.url,
    required this.bitrate,
    required this.codec,
    required this.container,
    required this.size,
  });

  final String url;
  final int bitrate;
  final String codec;
  final String container;
  final int size;
}

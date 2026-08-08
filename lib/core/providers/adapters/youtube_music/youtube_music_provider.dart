// ════════════════════════════════════════════════
// V Shots — YouTube Music Provider
// ════════════════════════════════════════════════
//
// Implements IMusicProvider using YouTube Music.
// All YouTube-specific code is isolated here.
// The app never knows it's using YouTube.
// ════════════════════════════════════════════════

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:v_shots/core/cache/cache_key.dart';
import 'package:v_shots/core/cache/cache_manager.dart';
import 'package:v_shots/core/cache/policies/cache_policy.dart';
import 'package:v_shots/core/logging/app_logger.dart';
import 'package:v_shots/core/providers/imusic_provider.dart';
import 'package:v_shots/core/providers/models/provider_models.dart';
import 'youtube_music_client.dart';
import 'youtube_music_mapper.dart';

/// YouTube Music provider implementation.
///
/// Implements [IMusicProvider] to provide real music
/// content from YouTube/YouTube Music.
///
/// ```dart
/// final provider = YouTubeMusicProvider(cacheManager: cache);
/// await provider.initialize(ProviderInitConfig(apiKey: ''));
/// final results = await provider.search('Believer');
/// ```
class YouTubeMusicProvider implements IMusicProvider {
  YouTubeMusicProvider({
    required this.cacheManager,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final CacheManager cacheManager;
  final AppLogger _logger;

  late YouTubeMusicClient _client;
  bool _isInitialized = false;

  @override
  String get id => 'youtube_music';

  @override
  String get name => 'YouTube Music';

  @override
  String get version => '1.0.0';

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: true,
        supportsLyrics: false,
        supportsRecommendations: true,
        supportsTrending: true,
        supportsOffline: false,
        supportsHighQuality: true,
        supportsPodcasts: true,
        supportsAudiobooks: true,
        maxBitrate: 256,
        maxSearchResults: 50,
      );

  // ═══════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════

  @override
  Future<void> initialize(ProviderInitConfig config) async {
    if (_isInitialized) return;

    try {
      _client = YouTubeMusicClient(logger: _logger);
      await _client.initialize();
      _isInitialized = true;
      _logger.i('YouTubeMusicProvider: Initialized');
    } catch (e, st) {
      _logger.e('YouTubeMusicProvider: Init failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    _client.dispose();
    _isInitialized = false;
  }

  @override
  Future<HealthStatus> healthCheck() async {
    try {
      // Try a simple search to verify connectivity.
      final results = await _client.search('test', limit: 1);
      return HealthStatus(
        isHealthy: results.isNotEmpty,
        lastChecked: DateTime.now(),
        message: results.isNotEmpty ? 'OK' : 'No results',
      );
    } catch (e) {
      return HealthStatus(
        isHealthy: false,
        lastChecked: DateTime.now(),
        message: e.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════
  // SEARCH
  // ═══════════════════════════════════════════════

  @override
  Future<ProviderSearchResult> search(
    String query, {
    SearchFilter? filter,
    int page = 1,
    int limit = 20,
  }) async {
    _logger.d('YouTubeMusicProvider: Searching "$query"');

    // Check cache.
    final cacheKey = CacheKey(namespace: 'yt_search', id: '$query:$page:$limit');
    final cached = cacheManager.getRaw(cacheKey);
    if (cached != null) {
      _logger.d('YouTubeMusicProvider: Search cache hit');
      // TODO: Deserialize cached result.
    }

    try {
      final videos = await _client.search(query, limit: limit);
      final result = YouTubeMusicMapper.searchResultsToModel(videos, query);

      // Cache the result.
      // await cacheManager.putRaw(cacheKey, result.toJson().toString());

      return result;
    } catch (e, st) {
      _logger.e('YouTubeMusicProvider: Search failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<String>> getSuggestions(String query) async {
    try {
      return await _client.getSearchSuggestions(query);
    } catch (e) {
      _logger.w('YouTubeMusicProvider: Suggestions failed');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // TRACKS
  // ═══════════════════════════════════════════════

  @override
  Future<ProviderTrack> getTrack(String id) async {
    _logger.d('YouTubeMusicProvider: Getting track $id');

    // Check cache.
    final cacheKey = CacheKey(namespace: 'yt_tracks', id: id);
    final cached = cacheManager.getRaw(cacheKey);
    // TODO: Check cache.

    try {
      final video = await _client.getVideo(id);
      if (video == null) {
        throw Exception('Track not found: $id');
      }

      final track = YouTubeMusicMapper.videoToTrack(video);

      // Cache the result.
      // await cacheManager.putRaw(cacheKey, track.toJson().toString());

      return track;
    } catch (e, st) {
      _logger.e('YouTubeMusicProvider: getTrack failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<ProviderTrack>> getTracks(List<String> ids) async {
    try {
      final videos = await _client.getVideos(ids);
      return videos.map(YouTubeMusicMapper.videoToTrack).toList();
    } catch (e, st) {
      _logger.e('YouTubeMusicProvider: getTracks failed', error: e, stackTrace: st);
      return [];
    }
  }

  @override
  Future<ProviderStreamInfo> getStream(String id, {StreamQuality? quality}) async {
    _logger.d('YouTubeMusicProvider: Getting stream for $id');

    try {
      final streamInfo = await _client.getAudioStream(id);
      if (streamInfo == null) {
        throw Exception('No stream available for $id');
      }

      return YouTubeMusicMapper.streamToModel(
        id,
        streamInfo.url,
        streamInfo.bitrate,
        streamInfo.codec,
      );
    } catch (e, st) {
      _logger.e('YouTubeMusicProvider: getStream failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<ProviderLyrics?> getLyrics(String id) async {
    // YouTube doesn't provide structured lyrics.
    // Return null - lyrics can be fetched from other sources.
    _logger.d('YouTubeMusicProvider: Lyrics not available for $id');
    return null;
  }

  // ═══════════════════════════════════════════════
  // ALBUMS
  // ═══════════════════════════════════════════════

  @override
  Future<ProviderAlbum> getAlbum(String id) async {
    _logger.d('YouTubeMusicProvider: Getting album $id');

    try {
      // YouTube doesn't have native albums.
      // Try to get as a video and convert.
      final video = await _client.getVideo(id);
      if (video == null) {
        throw Exception('Album not found: $id');
      }
      return YouTubeMusicMapper.videoToAlbum(video);
    } catch (e, st) {
      _logger.e('YouTubeMusicProvider: getAlbum failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<ProviderTrack>> getAlbumTracks(String id, {int page = 1, int limit = 50}) async {
    _logger.d('YouTubeMusicProvider: Getting album tracks for $id');

    try {
      // Try to get as playlist if it's a playlist ID.
      final videos = await _client.getPlaylistVideos(id, limit: limit);
      return videos.map(YouTubeMusicMapper.videoToTrack).toList();
    } catch (e) {
      // If not a playlist, try as single video.
      final video = await _client.getVideo(id);
      if (video != null) {
        return [YouTubeMusicMapper.videoToTrack(video)];
      }
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // ARTISTS
  // ═══════════════════════════════════════════════

  @override
  Future<ProviderArtist> getArtist(String id) async {
    _logger.d('YouTubeMusicProvider: Getting artist $id');

    try {
      final channel = await _client.getChannel(id);
      if (channel == null) {
        throw Exception('Artist not found: $id');
      }
      return YouTubeMusicMapper.channelToArtist(channel);
    } catch (e, st) {
      _logger.e('YouTubeMusicProvider: getArtist failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<ProviderTrack>> getArtistTopTracks(String id, {int limit = 10}) async {
    _logger.d('YouTubeMusicProvider: Getting top tracks for $id');

    try {
      final videos = await _client.getChannelVideos(id, limit: limit);
      return videos.map(YouTubeMusicMapper.videoToTrack).toList();
    } catch (e, st) {
      _logger.e('YouTubeMusicProvider: getArtistTopTracks failed', error: e, stackTrace: st);
      return [];
    }
  }

  @override
  Future<List<ProviderAlbum>> getArtistAlbums(String id, {int page = 1, int limit = 20}) async {
    // YouTube doesn't have native album support.
    // Return empty - albums can be found via search.
    _logger.d('YouTubeMusicProvider: Albums not directly available for artist $id');
    return [];
  }

  @override
  Future<List<ProviderArtist>> getRelatedArtists(String id, {int limit = 10}) async {
    // YouTube doesn't have direct related artists.
    // Return empty for now.
    _logger.d('YouTubeMusicProvider: Related artists not available for $id');
    return [];
  }

  // ═══════════════════════════════════════════════
  // PLAYLISTS
  // ═══════════════════════════════════════════════

  @override
  Future<ProviderPlaylist> getPlaylist(String id) async {
    _logger.d('YouTubeMusicProvider: Getting playlist $id');

    try {
      final playlist = await _client.getPlaylistVideos(id, limit: 1);
      // Get playlist metadata from first video or client.
      // For now, create a basic model.
      return ProviderPlaylist(
        id: id,
        title: 'Playlist',
        trackCount: playlist.length,
        metadata: {'youtube_playlist_id': id},
      );
    } catch (e, st) {
      _logger.e('YouTubeMusicProvider: getPlaylist failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<ProviderTrack>> getPlaylistTracks(String id, {int page = 1, int limit = 50}) async {
    _logger.d('YouTubeMusicProvider: Getting playlist tracks for $id');

    try {
      final videos = await _client.getPlaylistVideos(id, limit: limit);
      return videos.map(YouTubeMusicMapper.videoToTrack).toList();
    } catch (e, st) {
      _logger.e('YouTubeMusicProvider: getPlaylistTracks failed', error: e, stackTrace: st);
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // RECOMMENDATIONS
  // ═══════════════════════════════════════════════

  @override
  Future<List<ProviderTrack>> getRecommendations({
    List<String>? seedTrackIds,
    List<String>? seedArtistIds,
    int limit = 20,
  }) async {
    _logger.d('YouTubeMusicProvider: Getting recommendations');

    try {
      if (seedTrackIds != null && seedTrackIds.isNotEmpty) {
        // Get related videos for the first seed track.
        final related = await _client.getRelatedVideos(seedTrackIds.first, limit: limit);
        return related.map(YouTubeMusicMapper.videoToTrack).toList();
      }

      // If no seeds, return trending.
      return getTrending(limit: limit);
    } catch (e, st) {
      _logger.e('YouTubeMusicProvider: getRecommendations failed', error: e, stackTrace: st);
      return [];
    }
  }

  @override
  Future<List<ProviderTrack>> getTrending({String? genre, String? region, int limit = 20}) async {
    _logger.d('YouTubeMusicProvider: Getting trending');

    try {
      // Search for popular music.
      final query = genre != null ? '$genre music 2024' : 'trending music 2024';
      final videos = await _client.search(query, limit: limit);
      return videos.map(YouTubeMusicMapper.videoToTrack).toList();
    } catch (e, st) {
      _logger.e('YouTubeMusicProvider: getTrending failed', error: e, stackTrace: st);
      return [];
    }
  }

  @override
  Future<List<ProviderAlbum>> getNewReleases({String? region, int limit = 20}) async {
    _logger.d('YouTubeMusicProvider: Getting new releases');

    try {
      final videos = await _client.search('new music 2024', limit: limit);
      return videos.map(YouTubeMusicMapper.videoToAlbum).toList();
    } catch (e, st) {
      _logger.e('YouTubeMusicProvider: getNewReleases failed', error: e, stackTrace: st);
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // ARTWORK
  // ═══════════════════════════════════════════════

  @override
  Future<String?> getArtwork(String id, {ArtworkSize size = ArtworkSize.medium}) async {
    try {
      final video = await _client.getVideo(id);
      if (video == null) return null;

      // Return appropriate thumbnail size.
      switch (size) {
        case ArtworkSize.small:
          return video.thumbnails.lowResUrl.toString();
        case ArtworkSize.medium:
          return video.thumbnails.mediumResUrl.toString();
        case ArtworkSize.large:
        case ArtworkSize.original:
          return video.thumbnails.highResUrl.toString();
      }
    } catch (e) {
      _logger.w('YouTubeMusicProvider: getArtwork failed');
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // GENRES
  // ═══════════════════════════════════════════════

  @override
  Future<List<String>> getGenres() async {
    return [
      'Pop',
      'Rock',
      'Hip-Hop',
      'R&B',
      'Electronic',
      'Dance',
      'Classical',
      'Jazz',
      'Country',
      'Latin',
      'K-Pop',
      'Bollywood',
      'Indie',
      'Metal',
      'Folk',
    ];
  }
}

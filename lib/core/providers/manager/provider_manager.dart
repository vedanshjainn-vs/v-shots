// ════════════════════════════════════════════════
// Project Lyra — Provider Manager
// ════════════════════════════════════════════════
//
// Simple provider manager that:
// - Uses the active provider from config
// - Falls back to fallback provider on failure
// - Caches responses when enabled
//
// The Flutter app only talks to this class.
// It never knows which provider is active.
// ════════════════════════════════════════════════

import '../../../config/provider_config.dart';
import '../../cache/cache_key.dart';
import '../../cache/cache_manager.dart';
import '../../cache/policies/cache_policy.dart';
import '../../logging/app_logger.dart';
import '../imusic_provider.dart';
import '../models/provider_models.dart';
import '../registry/provider_registry.dart';

/// Unified music provider API.
///
/// The Flutter app only talks to this class.
/// It routes requests to the active provider,
/// handles failover, and caching.
///
/// ```dart
/// final manager = ProviderManager(registry: registry, cacheManager: cache);
/// final track = await manager.getTrack('abc123');
/// final results = await manager.search('query');
/// ```
class ProviderManager {
  ProviderManager({
    required this.registry,
    required this.cacheManager,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final ProviderRegistry registry;
  final CacheManager cacheManager;
  final AppLogger _logger;

  // ── Search ───────────────────────────────────

  Future<ProviderSearchResult> search(
    String query, {
    SearchFilter? filter,
    int page = 1,
    int limit = 20,
  }) {
    return _execute(
      operation: 'search',
      execute: (provider) => provider.search(query, filter: filter, page: page, limit: limit),
      cacheKey: CacheKey(namespace: 'search', id: '$query:$page:$limit'),
      cacheTTL: ProviderConfig.searchCacheDuration,
    );
  }

  Future<List<String>> getSuggestions(String query) {
    return _execute(
      operation: 'getSuggestions',
      execute: (provider) => provider.getSuggestions(query),
    );
  }

  // ── Tracks ───────────────────────────────────

  Future<ProviderTrack> getTrack(String id) {
    return _execute(
      operation: 'getTrack',
      execute: (provider) => provider.getTrack(id),
      cacheKey: CacheKey(namespace: 'tracks', id: id),
      cacheTTL: ProviderConfig.metadataCacheDuration,
    );
  }

  Future<List<ProviderTrack>> getTracks(List<String> ids) {
    return _execute(
      operation: 'getTracks',
      execute: (provider) => provider.getTracks(ids),
    );
  }

  Future<ProviderStreamInfo> getStream(String id, {StreamQuality? quality}) {
    return _execute(
      operation: 'getStream',
      execute: (provider) => provider.getStream(id, quality: quality),
      cacheKey: CacheKey(namespace: 'streams', id: id),
      cacheTTL: ProviderConfig.streamCacheDuration,
    );
  }

  Future<ProviderLyrics?> getLyrics(String id) {
    return _execute(
      operation: 'getLyrics',
      execute: (provider) => provider.getLyrics(id),
      cacheKey: CacheKey(namespace: 'lyrics', id: id),
      cacheTTL: const Duration(days: 7),
    );
  }

  // ── Albums ───────────────────────────────────

  Future<ProviderAlbum> getAlbum(String id) {
    return _execute(
      operation: 'getAlbum',
      execute: (provider) => provider.getAlbum(id),
      cacheKey: CacheKey(namespace: 'albums', id: id),
      cacheTTL: ProviderConfig.metadataCacheDuration,
    );
  }

  Future<List<ProviderTrack>> getAlbumTracks(String id, {int page = 1, int limit = 50}) {
    return _execute(
      operation: 'getAlbumTracks',
      execute: (provider) => provider.getAlbumTracks(id, page: page, limit: limit),
    );
  }

  // ── Artists ──────────────────────────────────

  Future<ProviderArtist> getArtist(String id) {
    return _execute(
      operation: 'getArtist',
      execute: (provider) => provider.getArtist(id),
      cacheKey: CacheKey(namespace: 'artists', id: id),
      cacheTTL: ProviderConfig.metadataCacheDuration,
    );
  }

  Future<List<ProviderTrack>> getArtistTopTracks(String id, {int limit = 10}) {
    return _execute(
      operation: 'getArtistTopTracks',
      execute: (provider) => provider.getArtistTopTracks(id, limit: limit),
    );
  }

  Future<List<ProviderAlbum>> getArtistAlbums(String id, {int page = 1, int limit = 20}) {
    return _execute(
      operation: 'getArtistAlbums',
      execute: (provider) => provider.getArtistAlbums(id, page: page, limit: limit),
    );
  }

  // ── Playlists ────────────────────────────────

  Future<ProviderPlaylist> getPlaylist(String id) {
    return _execute(
      operation: 'getPlaylist',
      execute: (provider) => provider.getPlaylist(id),
    );
  }

  Future<List<ProviderTrack>> getPlaylistTracks(String id, {int page = 1, int limit = 50}) {
    return _execute(
      operation: 'getPlaylistTracks',
      execute: (provider) => provider.getPlaylistTracks(id, page: page, limit: limit),
    );
  }

  // ── Recommendations ──────────────────────────

  Future<List<ProviderTrack>> getRecommendations({
    List<String>? seedTrackIds,
    List<String>? seedArtistIds,
    int limit = 20,
  }) {
    return _execute(
      operation: 'getRecommendations',
      execute: (provider) => provider.getRecommendations(
        seedTrackIds: seedTrackIds,
        seedArtistIds: seedArtistIds,
        limit: limit,
      ),
    );
  }

  Future<List<ProviderTrack>> getTrending({String? genre, int limit = 20}) {
    return _execute(
      operation: 'getTrending',
      execute: (provider) => provider.getTrending(genre: genre, limit: limit),
    );
  }

  Future<List<ProviderAlbum>> getNewReleases({String? region, int limit = 20}) {
    return _execute(
      operation: 'getNewReleases',
      execute: (provider) => provider.getNewReleases(region: region, limit: limit),
    );
  }

  // ── Artwork ──────────────────────────────────

  Future<String?> getArtwork(String id, {ArtworkSize size = ArtworkSize.medium}) {
    return _execute(
      operation: 'getArtwork',
      execute: (provider) => provider.getArtwork(id, size: size),
    );
  }

  // ── Core Execution Logic ─────────────────────

  /// Execute a request with failover and optional caching.
  Future<T> _execute<T>({
    required String operation,
    required Future<T> Function(IMusicProvider) execute,
    CacheKey? cacheKey,
    Duration? cacheTTL,
  }) async {
    // 1. Check cache (if enabled and key provided).
    if (ProviderConfig.cacheEnabled && cacheKey != null) {
      final cached = cacheManager.getRaw(cacheKey);
      if (cached != null) {
        _logger.d('ProviderManager: Cache hit for $operation');
        // TODO(team): Deserialize cached data to T.
        // For now, fall through to provider.
      }
    }

    // 2. Get active provider.
    final provider = registry.getActiveProvider();
    if (provider == null) {
      throw ProviderException('No active provider registered');
    }

    // 3. Try active provider.
    try {
      final result = await execute(provider);

      // Cache the result.
      if (ProviderConfig.cacheEnabled && cacheKey != null) {
        // TODO(team): Serialize result and cache.
      }

      return result;
    } catch (e) {
      _logger.e('ProviderManager: $operation failed on ${provider.id}', error: e);

      // 4. Try fallback (if allowed).
      if (ProviderConfig.allowFallback) {
        final fallback = registry.getFallbackProvider();
        if (fallback != null) {
          _logger.i('ProviderManager: Trying fallback provider');
          try {
            return await execute(fallback);
          } catch (fallbackError) {
            _logger.e('ProviderManager: Fallback also failed', error: fallbackError);
            rethrow;
          }
        }
      }

      rethrow;
    }
  }
}

/// Exception thrown by the provider system.
class ProviderException implements Exception {
  const ProviderException(this.message);
  final String message;

  @override
  String toString() => 'ProviderException: $message';
}

// ═════════════════════════════════════════════════════════════════════════════
// V Shots — InnerTubeMusicProvider (primary discovery provider)
// ═════════════════════════════════════════════════════════════════════════════
//
// The FIRST provider in ProviderManager's priority order. It resolves
// discovery metadata through InnerTube (YouTube's own web data endpoints),
// giving Home / Discovery / Search the same live, real catalog YouTube shows.
//
// It deliberately does NOT implement getStream / getTrack-audio: playback is
// the official YouTube IFrame player, never stream extraction. If this
// provider fails or returns nothing, ProviderManager fails over to the
// YouTube Data API v3 provider (which itself falls back to a curated catalog).
// ═════════════════════════════════════════════════════════════════════════════

import '../../../innertube/inner_tube_client.dart';
import '../../../innertube/inner_tube_normalizer.dart';
import '../../music_provider.dart';
import '../../provider_models.dart';
import '../../provider_result.dart';

class InnerTubeMusicProvider extends MusicProvider {
  InnerTubeMusicProvider({
    InnerTubeClient? client,
    InnerTubeNormalizer normalizer = const InnerTubeNormalizer(),
  }) : _client = client ?? InnerTubeClient(),
       _normalizer = normalizer;

  final InnerTubeClient _client;
  final InnerTubeNormalizer _normalizer;

  @override
  String get id => 'innertube';

  @override
  String get displayName => 'InnerTube';

  @override
  Set<ProviderCapability> get capabilities => const {
    ProviderCapability.search,
    ProviderCapability.getTrending,
    ProviderCapability.getRecommendations,
    ProviderCapability.getRelated,
  };

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<ProviderHealth> healthCheck() async {
    if (!_initialized) {
      return const ProviderHealth(healthy: false, message: 'not initialized');
    }
    try {
      final items = await _client.search('music', limit: 1);
      return ProviderHealth(
        healthy: true,
        message: 'ok (${items.length} result)',
      );
    } catch (e) {
      return ProviderHealth(healthy: false, message: '$e');
    }
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> search(
    String query, {
    String order = 'relevance',
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async {
    try {
      // Fetch extra so quality filtering can still fill the requested limit.
      final items = await _client.search(
        query,
        limit: limit * 2,
        order: order,
        excludeIds: excludeIds,
      );
      final tracks = _normalizer.mapSearchResults(
        items,
        limit: limit,
        maxMinutes: maxDurationMinutes,
        minMinutes: minDurationMinutes,
        excludeIds: excludeIds,
      );
      // Empty (or fully filtered) results are reported as a FAILURE so the
      // ProviderManager fails over to the YouTube Data API provider (and its
      // curated catalog) — a shelf must never come back empty just because
      // InnerTube returned nothing usable.
      if (tracks.isEmpty) {
        return ProviderResult.failure('InnerTube returned no usable results');
      }
      return ProviderResult.success(tracks);
    } catch (e) {
      return ProviderResult.failure('InnerTube search failed: $e');
    }
  }

  @override
  Future<ProviderResult<ProviderSearchPage>> searchPage(
    String query, {
    String order = 'relevance',
    int limit = 20,
    Set<String> excludeIds = const {},
    String? pageToken,
  }) async {
    try {
      final page = await _client.searchPage(
        query,
        limit: limit * 2,
        order: order,
        excludeIds: excludeIds,
        continuationToken: pageToken,
      );
      final tracks = _normalizer.mapSearchResults(
        page.items,
        limit: limit,
        excludeIds: excludeIds,
      );
      if (tracks.isEmpty) {
        return ProviderResult.failure('InnerTube page had no usable results');
      }
      return ProviderResult.success(
        ProviderSearchPage(
          tracks: tracks,
          nextPageToken: page.continuationToken,
        ),
      );
    } catch (e) {
      return ProviderResult.failure('InnerTube searchPage failed: $e');
    }
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> getTrending({
    int limit = 15,
  }) async {
    return search('trending music hits official audio', limit: limit);
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  }) async {
    return search(
      'popular music hits playlist',
      limit: limit,
      excludeIds: excludeIds,
    );
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> getRelated(
    String trackId, {
    int limit = 10,
  }) async {
    try {
      // Fetch extra so the shared quality filter can still fill the limit
      // (related lockups carry no duration, so the filter's duration cap
      // won't drop them; title/keyword filtering still applies).
      final items = await _client.related(trackId, limit: limit * 2);
      final tracks = _normalizer.mapSearchResults(
        items,
        limit: limit,
        excludeIds: {trackId},
      );
      if (tracks.isEmpty) {
        return ProviderResult.failure('InnerTube related returned nothing');
      }
      return ProviderResult.success(tracks);
    } catch (e) {
      return ProviderResult.failure('InnerTube related failed: $e');
    }
  }

  @override
  Future<ProviderResult<ProviderTrack>> getTrack(String id) async {
    return ProviderResult.failure(
      'InnerTube is metadata-only; use the official YouTube player for playback.',
    );
  }

  @override
  Future<ProviderResult<String>> getStream(String id) async {
    return ProviderResult.failure(
      'Stream extraction is prohibited. Use the official YouTube player.',
    );
  }

  @override
  Future<ProviderResult<String>> getArtwork(String id) async {
    return ProviderResult.failure('InnerTube does not expose artwork by id.');
  }

  @override
  Future<ProviderResult<ProviderLyrics>> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  }) async {
    return ProviderResult.failure('InnerTube does not provide lyrics.');
  }

  @override
  Future<void> dispose() async {
    await _client.dispose();
  }
}

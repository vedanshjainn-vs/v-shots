// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Provider Architecture: ProviderManager
// ═════════════════════════════════════════════════════════════════════════════

import 'music_provider.dart';
import 'provider_config.dart';
import 'provider_models.dart';
import 'provider_registry.dart';
import 'provider_result.dart';

class ProviderManager {
  ProviderManager({
    required this.registry,
    this.config = ProviderConfig.defaultConfig,
  });

  final ProviderRegistry registry;
  final ProviderConfig config;

  bool _initialized = false;

  Future<void> initializeAll() async {
    if (_initialized) return;
    _initialized = true;
    for (final provider in registry.inPriorityOrder(config)) {
      try {
        await provider.initialize();
      } catch (_) {}
    }
  }

  MusicProvider? get activeProvider => registry[config.activeProvider];

  Future<Map<String, ProviderHealth>> checkAllHealth() async {
    final results = <String, ProviderHealth>{};
    for (final provider in registry.inPriorityOrder(config)) {
      try {
        results[provider.id] = await provider.healthCheck();
      } catch (e) {
        results[provider.id] = ProviderHealth(healthy: false, message: '$e');
      }
    }
    return results;
  }

  Future<ProviderResult<T>> _routeWithFailover<T>(
    ProviderCapability capability,
    Future<ProviderResult<T>> Function(MusicProvider provider) attempt,
  ) async {
    final candidates = registry
        .inPriorityOrder(config)
        .where((p) => p.supports(capability))
        .toList();

    if (candidates.isEmpty) {
      return ProviderResult.failure('No provider supports ${capability.name}');
    }

    String? lastError;
    for (final provider in candidates) {
      try {
        final result = await attempt(provider);
        if (result.isSuccess) return result;
        lastError = result.error;
      } catch (e) {
        lastError = '$e';
      }
    }
    return ProviderResult.failure(
      lastError ?? 'All providers failed for ${capability.name}',
    );
  }

  Future<ProviderResult<List<ProviderTrack>>> search(
    String query, {
    String order = 'relevance',
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) {
    return _routeWithFailover(
      ProviderCapability.search,
      (p) => p.search(
        query,
        order: order,
        limit: limit,
        maxDurationMinutes: maxDurationMinutes,
        minDurationMinutes: minDurationMinutes,
        excludeIds: excludeIds,
      ),
    );
  }

  Future<ProviderResult<ProviderSearchPage>> searchPage(
    String query, {
    String order = 'relevance',
    int limit = 20,
    Set<String> excludeIds = const {},
    String? pageToken,
  }) {
    return _routeWithFailover(
      ProviderCapability.search,
      (p) => p.searchPage(
        query,
        order: order,
        limit: limit,
        excludeIds: excludeIds,
        pageToken: pageToken,
      ),
    );
  }

  Future<ProviderResult<ProviderTrack>> getTrack(String id) {
    return _routeWithFailover(
      ProviderCapability.getTrack,
      (p) => p.getTrack(id),
    );
  }

  Future<ProviderResult<String>> getStream(String id) {
    return _routeWithFailover(
      ProviderCapability.getStream,
      (p) => p.getStream(id),
    );
  }

  Future<ProviderResult<String>> getArtwork(String id) {
    return _routeWithFailover(
      ProviderCapability.getArtwork,
      (p) => p.getArtwork(id),
    );
  }

  Future<ProviderResult<ProviderLyrics>> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  }) {
    return _routeWithFailover(
      ProviderCapability.getLyrics,
      (p) => p.getLyrics(
        trackName: trackName,
        artistName: artistName,
        durationSeconds: durationSeconds,
      ),
    );
  }

  Future<ProviderResult<List<ProviderTrack>>> getTrending({int limit = 15}) {
    return _routeWithFailover(
      ProviderCapability.getTrending,
      (p) => p.getTrending(limit: limit),
    );
  }

  Future<ProviderResult<List<ProviderTrack>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  }) {
    return _routeWithFailover(
      ProviderCapability.getRecommendations,
      (p) => p.getRecommendations(excludeIds: excludeIds, limit: limit),
    );
  }

  /// Related tracks for a given track ("More Like This"). Routed to the
  /// primary provider that declares [ProviderCapability.getRelated]
  /// (InnerTube); fails over through the priority order.
  Future<ProviderResult<List<ProviderTrack>>> getRelated(
    String trackId, {
    int limit = 10,
  }) {
    return _routeWithFailover(
      ProviderCapability.getRelated,
      (p) => p.getRelated(trackId, limit: limit),
    );
  }
}

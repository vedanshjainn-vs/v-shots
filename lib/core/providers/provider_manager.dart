// ════════════════════════════════════════════════
// V Shots — Provider Architecture: ProviderManager
// ════════════════════════════════════════════════
//
// The single entry point the rest of the app (via MusicRepository —
// see music_repository.dart) talks to for search/content/stream
// requests. Responsibilities (per the task's Phase 5 spec):
//   - register/initialize providers (delegates to ProviderRegistry)
//   - health-check providers
//   - expose the active provider
//   - route search/content/playback requests
//   - handle provider failures (falls through to the next provider in
//     priority order that supports the requested capability)
//   - prepare future fallback providers (the routing/failover loop
//     below already works for N providers — TODAY there is only one
//     registered, YouTube, so failover is inert until a second real
//     provider is added later; this is NOT simulated/faked).
// ════════════════════════════════════════════════

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

  /// Initializes every enabled provider (in priority order). Safe to
  /// call multiple times. A single provider's initialize() throwing
  /// does not prevent the others from initializing — matches
  /// SupabaseService's existing "one subsystem's failure must not take
  /// down the whole app" pattern elsewhere in this codebase.
  Future<void> initializeAll() async {
    if (_initialized) return;
    _initialized = true;
    for (final provider in registry.inPriorityOrder(config)) {
      try {
        await provider.initialize();
      } catch (e) {
        // Intentionally swallowed per-provider — a provider that fails
        // to initialize is simply treated as unhealthy by
        // _firstHealthyProviderFor() below, not a fatal app error.
      }
    }
  }

  /// The provider [config] currently designates as primary, if
  /// registered — null if not registered (e.g. misconfigured id).
  MusicProvider? get activeProvider => registry[config.activeProvider];

  /// Runs a real health check against every registered, enabled
  /// provider — exposed for diagnostics/tests. NOT called on every
  /// hot-path request (see [_routeWithFailover]'s doc for why):
  /// pre-flight-checking health before every single search/stream call
  /// would add a redundant network round-trip to every request, which
  /// directly conflicts with this task's Phase 9 performance goals
  /// ("prevent duplicate network requests"). Real failure handling
  /// instead happens by attempting the actual request and falling
  /// through to the next provider only if it genuinely fails.
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

  /// Tries [capability] against each registered provider (in priority
  /// order) that supports it, calling [attempt] on the first one and
  /// falling through to the next on failure. This is the app's one
  /// real failover mechanism: today there is exactly one registered
  /// provider (YouTube) so there is nothing to fall through TO yet —
  /// adding a second real provider later (Phase 6's "Future Provider")
  /// makes this loop actually exercise failover, with zero changes
  /// needed here.
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
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) {
    return _routeWithFailover(
      ProviderCapability.search,
      (p) => p.search(
        query,
        limit: limit,
        maxDurationMinutes: maxDurationMinutes,
        minDurationMinutes: minDurationMinutes,
        excludeIds: excludeIds,
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
}

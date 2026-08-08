// ════════════════════════════════════════════════
// Project Lyra — Cache Policy
// ════════════════════════════════════════════════
//
// Defines how data flows between cache layers
// and the network. Each endpoint can have its
// own policy for optimal freshness vs performance.
// ════════════════════════════════════════════════

/// Strategies for reading and writing cached data.
enum CacheStrategy {
  /// Cache-first: return cached data if available,
  /// otherwise fetch from network. Good for static content.
  cacheFirst,

  /// Network-first: always try network, fall back to cache.
  /// Good for dynamic content that must be fresh.
  networkFirst,

  /// Cache-only: never hit the network. Good for offline content.
  cacheOnly,

  /// Network-only: never use cache. Good for one-time operations.
  networkOnly,

  /// Stale-while-revalidate: return cache immediately,
  /// then update from network in background.
  staleWhileRevalidate,
}

/// Configuration for cache behavior.
///
/// Each feature/endpoint can define its own policy
/// to balance freshness vs performance.
///
/// ```dart
/// final policy = CachePolicy(
///   strategy: CacheStrategy.cacheFirst,
///   maxAge: Duration(hours: 1),
///   staleWhileRevalidate: true,
/// );
/// ```
class CachePolicy {
  /// Creates a cache policy.
  const CachePolicy({
    this.strategy = CacheStrategy.cacheFirst,
    this.maxAge = const Duration(hours: 1),
    this.maxStale = const Duration(days: 7),
    this.memoryMaxAge = const Duration(minutes: 5),
    this.forceRefresh = false,
    this.prefetchOnAccess = false,
    this.maxEntries,
  });

  /// Predefined policies for common scenarios.

  /// Static content that rarely changes (artist bios, album metadata).
  static const CachePolicy static = CachePolicy(
    strategy: CacheStrategy.cacheFirst,
    maxAge: Duration(days: 1),
    maxStale: Duration(days: 30),
    memoryMaxAge: Duration(hours: 1),
  );

  /// Dynamic content that changes frequently (feed, recommendations).
  static const CachePolicy dynamic = CachePolicy(
    strategy: CacheStrategy.staleWhileRevalidate,
    maxAge: Duration(minutes: 5),
    maxStale: Duration(hours: 1),
    memoryMaxAge: Duration(minutes: 2),
  );

  /// User-specific content (profile, library).
  static const CachePolicy userSpecific = CachePolicy(
    strategy: CacheStrategy.cacheFirst,
    maxAge: Duration(minutes: 15),
    maxStale: Duration(hours: 6),
    memoryMaxAge: Duration(minutes: 5),
  );

  /// Real-time content (now playing, live events).
  static const CachePolicy realtime = CachePolicy(
    strategy: CacheStrategy.networkOnly,
    maxAge: Duration.zero,
    maxStale: Duration.zero,
    memoryMaxAge: Duration.zero,
  );

  /// Offline-only content (downloaded tracks).
  static const CachePolicy offline = CachePolicy(
    strategy: CacheStrategy.cacheOnly,
    maxAge: Duration(days: 365),
    maxStale: Duration(days: 365),
    memoryMaxAge: Duration(hours: 24),
  );

  /// Search results (short-lived).
  static const CachePolicy search = CachePolicy(
    strategy: CacheStrategy.cacheFirst,
    maxAge: Duration(minutes: 30),
    maxStale: Duration(hours: 2),
    memoryMaxAge: Duration(minutes: 10),
    maxEntries: 100,
  );

  /// The primary strategy for reads.
  final CacheStrategy strategy;

  /// Maximum age before cache is considered stale.
  final Duration maxAge;

  /// Maximum age before stale cache is discarded entirely.
  final Duration maxStale;

  /// How long data stays in memory cache before being evicted.
  final Duration memoryMaxAge;

  /// Whether to force a network refresh regardless of cache state.
  final bool forceRefresh;

  /// Whether to prefetch related data when this key is accessed.
  final bool prefetchOnAccess;

  /// Maximum number of entries for this namespace (LRU eviction).
  final int? maxEntries;

  /// Whether the cached data is still fresh.
  bool isFresh(DateTime cachedAt) {
    return DateTime.now().difference(cachedAt) < maxAge;
  }

  /// Whether the cached data is still usable (stale but not expired).
  bool isUsable(DateTime cachedAt) {
    return DateTime.now().difference(cachedAt) < maxStale;
  }

  /// Whether memory-cached data is still valid.
  bool isMemoryFresh(DateTime cachedAt) {
    return DateTime.now().difference(cachedAt) < memoryMaxAge;
  }
}

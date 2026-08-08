// ════════════════════════════════════════════════
// Project Lyra — Cache Manager
// ════════════════════════════════════════════════
//
// Orchestrates the 3-tier cache hierarchy:
// Memory → Disk → Network.
//
// Repositories call CacheManager.get() and it
// automatically handles the data flow based on
// the configured CachePolicy.
// ════════════════════════════════════════════════

import '../logging/app_logger.dart';
import 'cache_key.dart';
import 'disk/disk_cache.dart';
import 'memory/memory_cache.dart';
import 'policies/cache_policy.dart';
import 'serialization/cache_serializer.dart';

/// Orchestrates the 3-tier caching system.
///
/// Data flow: Memory Cache → Disk Cache → Network Fetch
///
/// ```dart
/// final manager = CacheManager(memory: memCache, disk: diskCache);
///
/// // Automatic cache-first with fallback to network.
/// final tracks = await manager.get<Track>(
///   key: CacheKey.item('tracks', '123'),
///   policy: CachePolicy.static,
///   fromNetwork: () => api.getTrack('123'),
///   fromJson: (json) => Track.fromJson(json),
///   toJson: (track) => track.toJson(),
/// );
/// ```
class CacheManager {
  /// Creates a cache manager with memory and disk caches.
  CacheManager({
    required this.memory,
    required this.disk,
    this.serializer,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  /// In-memory LRU cache (Layer 1).
  final MemoryCache<String> memory;

  /// Persistent disk cache (Layer 2).
  final DiskCache disk;

  /// Serializer for complex objects.
  final CacheSerializer? serializer;

  final AppLogger _logger;

  // ── Read Operations ──────────────────────────

  /// Get data with automatic cache hierarchy resolution.
  ///
  /// Flow: Memory → Disk → Network (based on [policy]).
  Future<T?> get<T>({
    required CacheKey key,
    required CachePolicy policy,
    required Future<T> Function() fromNetwork,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
  }) async {
    // Force refresh bypasses cache.
    if (policy.forceRefresh) {
      return _fetchAndCache(
        key: key,
        policy: policy,
        fromNetwork: fromNetwork,
        toJson: toJson,
      );
    }

    switch (policy.strategy) {
      case CacheStrategy.cacheFirst:
        return _cacheFirst(
          key: key,
          policy: policy,
          fromNetwork: fromNetwork,
          fromJson: fromJson,
          toJson: toJson,
        );

      case CacheStrategy.networkFirst:
        return _networkFirst(
          key: key,
          policy: policy,
          fromNetwork: fromNetwork,
          fromJson: fromJson,
          toJson: toJson,
        );

      case CacheStrategy.cacheOnly:
        return _cacheOnly(
          key: key,
          fromJson: fromJson,
        );

      case CacheStrategy.networkOnly:
        return _fetchAndCache(
          key: key,
          policy: policy,
          fromNetwork: fromNetwork,
          toJson: toJson,
        );

      case CacheStrategy.staleWhileRevalidate:
        return _staleWhileRevalidate(
          key: key,
          policy: policy,
          fromNetwork: fromNetwork,
          fromJson: fromJson,
          toJson: toJson,
        );
    }
  }

  /// Get raw JSON from cache (memory or disk).
  String? getRaw(CacheKey key) {
    // Layer 1: Memory.
    final memResult = memory.getData(key);
    if (memResult != null) return memResult;

    // Layer 2: Disk.
    return disk.get(key);
  }

  // ── Write Operations ─────────────────────────

  /// Put data into both cache layers.
  Future<void> put<T>({
    required CacheKey key,
    required T data,
    required Map<String, dynamic> Function(T) toJson,
    Duration? ttl,
    String? etag,
  }) async {
    try {
      final json = serializer?.toJson(data, toJson) ?? '';

      // Layer 1: Memory.
      memory.put(key, json, etag: etag);

      // Layer 2: Disk.
      await disk.put(key, json, ttl: ttl, etag: etag);
    } catch (e, st) {
      _logger.e('CacheManager.put failed', error: e, stackTrace: st);
    }
  }

  /// Put raw JSON into both cache layers.
  Future<void> putRaw(CacheKey key, String data, {Duration? ttl}) async {
    memory.put(key, data);
    await disk.put(key, data, ttl: ttl);
  }

  // ── Invalidation ─────────────────────────────

  /// Remove a specific key from all layers.
  Future<void> invalidate(CacheKey key) async {
    memory.remove(key);
    await disk.remove(key);
  }

  /// Remove all entries in a namespace from all layers.
  Future<void> invalidateNamespace(String namespace) async {
    memory.removeByNamespace(namespace);
    await disk.removeByNamespace(namespace);
  }

  /// Clear all caches.
  Future<void> clearAll() async {
    memory.clear();
    await disk.clear();
  }

  /// Purge expired entries from disk cache.
  Future<int> purgeExpired() async {
    return disk.purgeExpired();
  }

  // ── Statistics ───────────────────────────────

  /// Get combined cache statistics.
  CacheManagerStats getStats() {
    return CacheManagerStats(
      memoryStats: memory.stats,
      diskStats: disk.getStats(),
      memoryEntries: memory.length,
      diskEntries: disk.length,
    );
  }

  // ── Private Strategy Implementations ─────────

  Future<T?> _cacheFirst<T>({
    required CacheKey key,
    required CachePolicy policy,
    required Future<T> Function() fromNetwork,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
  }) async {
    // Layer 1: Memory.
    final memResult = memory.getData(key);
    if (memResult != null) {
      _logger.d('CacheManager: Memory hit for ${key.value}');
      return serializer?.fromJson(memResult, fromJson);
    }

    // Layer 2: Disk.
    final diskResult = disk.get(key);
    if (diskResult != null) {
      _logger.d('CacheManager: Disk hit for ${key.value}');
      // Promote to memory.
      memory.put(key, diskResult);
      return serializer?.fromJson(diskResult, fromJson);
    }

    // Layer 3: Network.
    _logger.d('CacheManager: Cache miss, fetching from network for ${key.value}');
    return _fetchAndCache(
      key: key,
      policy: policy,
      fromNetwork: fromNetwork,
      toJson: toJson,
    );
  }

  Future<T?> _networkFirst<T>({
    required CacheKey key,
    required CachePolicy policy,
    required Future<T> Function() fromNetwork,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
  }) async {
    try {
      return await _fetchAndCache(
        key: key,
        policy: policy,
        fromNetwork: fromNetwork,
        toJson: toJson,
      );
    } catch (e) {
      _logger.w('CacheManager: Network failed, falling back to cache for ${key.value}');
      return _cacheOnly(key: key, fromJson: fromJson);
    }
  }

  Future<T?> _cacheOnly<T>({
    required CacheKey key,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    // Layer 1: Memory.
    final memResult = memory.getData(key);
    if (memResult != null) return serializer?.fromJson(memResult, fromJson);

    // Layer 2: Disk.
    final diskResult = disk.get(key);
    if (diskResult != null) {
      memory.put(key, diskResult);
      return serializer?.fromJson(diskResult, fromJson);
    }

    return null;
  }

  Future<T?> _staleWhileRevalidate<T>({
    required CacheKey key,
    required CachePolicy policy,
    required Future<T> Function() fromNetwork,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
  }) async {
    // Return cached data immediately (even if stale).
    T? cached;

    final memResult = memory.getData(key);
    if (memResult != null) {
      cached = serializer?.fromJson(memResult, fromJson);
    } else {
      final diskResult = disk.get(key);
      if (diskResult != null) {
        memory.put(key, diskResult);
        cached = serializer?.fromJson(diskResult, fromJson);
      }
    }

    // Revalidate in background (fire-and-forget).
    _fetchAndCache(
      key: key,
      policy: policy,
      fromNetwork: fromNetwork,
      toJson: toJson,
    ).catchError((e) {
      _logger.w('CacheManager: Background revalidation failed for ${key.value}');
      return null as T?;
    });

    return cached;
  }

  Future<T?> _fetchAndCache<T>({
    required CacheKey key,
    required CachePolicy policy,
    required Future<T> Function() fromNetwork,
    required Map<String, dynamic> Function(T) toJson,
  }) async {
    try {
      final data = await fromNetwork();

      if (data != null) {
        final json = serializer?.toJson(data, toJson) ?? '';

        // Layer 1: Memory.
        memory.put(key, json);

        // Layer 2: Disk.
        await disk.put(key, json, ttl: policy.maxAge);
      }

      return data;
    } catch (e, st) {
      _logger.e('CacheManager: Network fetch failed for ${key.value}',
          error: e, stackTrace: st);
      rethrow;
    }
  }
}

/// Combined cache manager statistics.
class CacheManagerStats {
  const CacheManagerStats({
    required this.memoryStats,
    required this.diskStats,
    required this.memoryEntries,
    required this.diskEntries,
  });

  final CacheStats memoryStats;
  final DiskCacheStats diskStats;
  final int memoryEntries;
  final int diskEntries;
}

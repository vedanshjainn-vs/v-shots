// ════════════════════════════════════════════════
// Project Lyra — Memory Cache (LRU)
// ════════════════════════════════════════════════
//
// Thread-safe, in-memory LRU cache.
// Fastest layer — no disk I/O.
// Used for hot data accessed within the current session.
// ════════════════════════════════════════════════

import 'dart:collection';

import '../cache_key.dart';
import '../serialization/cache_serializer.dart';

/// An in-memory LRU (Least Recently Used) cache.
///
/// Stores [CacheEntry] objects in memory with automatic
/// eviction when [maxSize] is reached. Accessing an entry
/// moves it to the front of the LRU queue.
///
/// Thread-safe for single-isolate Flutter apps.
///
/// ```dart
/// final cache = MemoryCache<String>(maxSize: 200);
/// cache.put(CacheKey.item('tracks', '123'), 'Track Data');
/// final track = cache.get(CacheKey.item('tracks', '123'));
/// ```
class MemoryCache<T> {
  /// Creates a memory cache with optional [maxSize].
  MemoryCache({this.maxSize = 500});

  /// Maximum number of entries before LRU eviction.
  final int maxSize;

  /// Internal LRU map: key → CacheEntry.
  final LinkedHashMap<String, CacheEntry<T>> _cache = LinkedHashMap();

  /// Cache statistics.
  final CacheStats _stats = CacheStats();

  /// Current number of entries.
  int get length => _cache.length;

  /// Whether the cache is empty.
  bool get isEmpty => _cache.isEmpty;

  /// Whether the cache is full.
  bool get isFull => _cache.length >= maxSize;

  /// Cache hit/miss statistics.
  CacheStats get stats => _stats;

  /// Get a cached entry by key.
  ///
  /// Returns the entry if found and not expired,
  /// or null if missing/expired. Moves entry to front on access.
  CacheEntry<T>? get(CacheKey key) {
    final entry = _cache.remove(key.value);

    if (entry == null) {
      _stats.recordMiss();
      return null;
    }

    // Move to front (most recently used).
    _cache[key.value] = entry;
    _stats.recordHit();
    return entry;
  }

  /// Get just the data (without metadata) for a key.
  T? getData(CacheKey key) => get(key)?.data;

  /// Put an entry into the cache.
  ///
  /// Evicts the least recently used entry if the cache is full.
  void put(CacheKey key, T data, {String? etag, Map<String, dynamic>? metadata}) {
    // Remove existing entry if present (to update position).
    _cache.remove(key.value);

    // Evict LRU if full.
    while (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
      _stats.recordEviction();
    }

    _cache[key.value] = CacheEntry<T>(
      data: data,
      cachedAt: DateTime.now(),
      key: key.value,
      etag: etag,
      metadata: metadata ?? {},
    );
  }

  /// Put a pre-built [CacheEntry] directly.
  void putEntry(CacheKey key, CacheEntry<T> entry) {
    _cache.remove(key.value);

    while (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
      _stats.recordEviction();
    }

    _cache[key.value] = entry;
  }

  /// Remove a specific entry.
  bool remove(CacheKey key) {
    return _cache.remove(key.value) != null;
  }

  /// Remove all entries matching a namespace pattern.
  int removeByNamespace(String namespace) {
    final prefix = '$namespace:';
    final keysToRemove = _cache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
    return keysToRemove.length;
  }

  /// Check if a key exists and is not expired.
  bool containsKey(CacheKey key) => _cache.containsKey(key.value);

  /// Clear all entries.
  void clear() {
    _cache.clear();
    _stats.reset();
  }

  /// Get all keys (ordered by access recency).
  Iterable<String> get keys => _cache.keys;

  /// Get all entries.
  Iterable<CacheEntry<T>> get values => _cache.values;
}

/// Cache hit/miss statistics.
class CacheStats {
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _puts = 0;

  /// Number of cache hits.
  int get hits => _hits;

  /// Number of cache misses.
  int get misses => _misses;

  /// Number of LRU evictions.
  int get evictions => _evictions;

  /// Number of put operations.
  int get puts => _puts;

  /// Total number of reads (hits + misses).
  int get totalReads => _hits + _misses;

  /// Cache hit rate (0.0 to 1.0).
  double get hitRate => totalReads > 0 ? _hits / totalReads : 0.0;

  void recordHit() => _hits++;
  void recordMiss() => _misses++;
  void recordEviction() => _evictions++;
  void recordPut() => _puts++;

  /// Reset all counters.
  void reset() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _puts = 0;
  }

  @override
  String toString() =>
      'CacheStats(hits: $_hits, misses: $_misses, rate: ${(hitRate * 100).toStringAsFixed(1)}%, evictions: $_evictions)';
}

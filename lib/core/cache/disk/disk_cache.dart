// ════════════════════════════════════════════════
// Project Lyra — Disk Cache (Hive)
// ════════════════════════════════════════════════
//
// Persistent disk cache backed by Hive.
// Second layer in the cache hierarchy.
// Survives app restarts. LRU eviction by access time.
// ════════════════════════════════════════════════

import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/logging/app_logger.dart';
import '../cache_key.dart';
import '../serialization/cache_serializer.dart';

/// Persistent disk cache using Hive.
///
/// Stores serialized cache entries with timestamps
/// for TTL-based expiration and LRU eviction.
///
/// ```dart
/// final diskCache = await DiskCache.open('tracks_cache');
/// await diskCache.put(key, jsonString);
/// final data = diskCache.get(key);
/// ```
class DiskCache {
  DiskCache._({required Box<String> box, required this.maxEntries})
      : _box = box;

  final Box<String> _box;
  final int maxEntries;
  final _logger = AppLogger.instance;

  /// Open a named disk cache box.
  static Future<DiskCache> open(
    String boxName, {
    int maxEntries = 1000,
  }) async {
    final box = await Hive.openBox<String>(boxName);
    return DiskCache._(box: box, maxEntries: maxEntries);
  }

  /// Current number of entries.
  int get length => _box.length;

  /// Whether the cache is empty.
  bool get isEmpty => _box.isEmpty;

  /// All keys in the cache.
  Iterable<String> get keys => _box.keys.cast<String>();

  /// Get a serialized cache entry by key.
  ///
  /// Returns the raw JSON string, or null if missing.
  /// The caller is responsible for deserialization.
  String? get(CacheKey key) {
    try {
      final raw = _box.get(key.value);
      if (raw == null) return null;

      // Check if entry has expired metadata.
      final entry = _deserializeMetadata(raw);
      if (entry != null && entry.isExpired) {
        // Lazy cleanup — remove expired entries on access.
        _box.delete(key.value);
        return null;
      }

      // Update access time for LRU.
      _updateAccessTime(key.value);
      return entry?.data ?? raw;
    } catch (e, st) {
      _logger.e('DiskCache.get failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Put a serialized entry into disk cache.
  Future<void> put(
    CacheKey key,
    String data, {
    Duration? ttl,
    String? etag,
  }) async {
    try {
      // Evict if at capacity.
      await _evictIfNeeded();

      final wrapped = _DiskCacheEntry(
        data: data,
        cachedAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
        ttl: ttl,
        etag: etag,
      );

      await _box.put(key.value, jsonEncode(wrapped.toMap()));
    } catch (e, st) {
      _logger.e('DiskCache.put failed', error: e, stackTrace: st);
    }
  }

  /// Remove a specific entry.
  Future<bool> remove(CacheKey key) async {
    try {
      await _box.delete(key.value);
      return true;
    } catch (e, st) {
      _logger.e('DiskCache.remove failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Remove all entries in a namespace.
  Future<int> removeByNamespace(String namespace) async {
    final prefix = '$namespace:';
    final keysToRemove = _box.keys
        .cast<String>()
        .where((k) => k.startsWith(prefix))
        .toList();

    await _box.deleteAll(keysToRemove);
    return keysToRemove.length;
  }

  /// Clear all entries.
  Future<void> clear() async {
    await _box.clear();
  }

  /// Check if a key exists.
  bool containsKey(CacheKey key) => _box.containsKey(key.value);

  /// Get cache statistics.
  DiskCacheStats getStats() {
    int totalSize = 0;
    int expiredCount = 0;
    final now = DateTime.now();

    for (final raw in _box.values) {
      totalSize += raw.length;
      final entry = _deserializeMetadata(raw);
      if (entry != null && entry.ttl != null) {
        if (now.difference(entry.cachedAt) > entry.ttl!) {
          expiredCount++;
        }
      }
    }

    return DiskCacheStats(
      entryCount: _box.length,
      totalSizeBytes: totalSize,
      expiredCount: expiredCount,
    );
  }

  /// Remove all expired entries.
  Future<int> purgeExpired() async {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final entry in _box.toMap().entries) {
      final meta = _deserializeMetadata(entry.value);
      if (meta != null && meta.ttl != null) {
        if (now.difference(meta.cachedAt) > meta.ttl!) {
          keysToRemove.add(entry.key.toString());
        }
      }
    }

    await _box.deleteAll(keysToRemove);
    return keysToRemove.length;
  }

  /// Evict oldest entries if at capacity (LRU).
  Future<void> _evictIfNeeded() async {
    if (_box.length < maxEntries) return;

    // Sort by lastAccessedAt and remove oldest.
    final entries = <(String, DateTime)>[];
    for (final key in _box.keys) {
      final raw = _box.get(key.toString());
      if (raw != null) {
        final meta = _deserializeMetadata(raw);
        if (meta != null) {
          entries.add((key.toString(), meta.lastAccessedAt));
        }
      }
    }

    entries.sort((a, b) => a.$2.compareTo(b.$2));

    // Remove oldest 10%.
    final removeCount = (maxEntries * 0.1).ceil();
    final toRemove = entries.take(removeCount).map((e) => e.$1).toList();
    await _box.deleteAll(toRemove);
  }

  void _updateAccessTime(String key) {
    final raw = _box.get(key);
    if (raw == null) return;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map['lastAccessedAt'] = DateTime.now().toIso8601String();
      _box.put(key, jsonEncode(map));
    } catch (_) {
      // Ignore update failures — non-critical.
    }
  }

  _DiskCacheEntry? _deserializeMetadata(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _DiskCacheEntry.fromMap(map);
    } catch (_) {
      // Legacy plain string entry — treat as non-expiring.
      return _DiskCacheEntry(
        data: raw,
        cachedAt: DateTime.fromMillisecondsSinceEpoch(0),
        lastAccessedAt: DateTime.now(),
      );
    }
  }
}

/// Internal disk cache entry with metadata.
class _DiskCacheEntry {
  const _DiskCacheEntry({
    required this.data,
    required this.cachedAt,
    required this.lastAccessedAt,
    this.ttl,
    this.etag,
  });

  final String data;
  final DateTime cachedAt;
  final DateTime lastAccessedAt;
  final Duration? ttl;
  final String? etag;

  bool get isExpired =>
      ttl != null && DateTime.now().difference(cachedAt) > ttl!;

  Map<String, dynamic> toMap() => {
        'data': data,
        'cachedAt': cachedAt.toIso8601String(),
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
        'ttl': ttl?.inMilliseconds,
        'etag': etag,
      };

  factory _DiskCacheEntry.fromMap(Map<String, dynamic> map) {
    return _DiskCacheEntry(
      data: map['data'] as String? ?? map.toString(),
      cachedAt: DateTime.parse(map['cachedAt'] as String),
      lastAccessedAt: DateTime.parse(map['lastAccessedAt'] as String),
      ttl: map['ttl'] != null
          ? Duration(milliseconds: map['ttl'] as int)
          : null,
      etag: map['etag'] as String?,
    );
  }
}

/// Disk cache statistics.
class DiskCacheStats {
  const DiskCacheStats({
    required this.entryCount,
    required this.totalSizeBytes,
    required this.expiredCount,
  });

  final int entryCount;
  final int totalSizeBytes;
  final int expiredCount;

  double get totalSizeMB => totalSizeBytes / (1024 * 1024);
}

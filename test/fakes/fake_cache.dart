// ════════════════════════════════════════════════
// Project Lyra — Fake Cache for Tests
// ════════════════════════════════════════════════

import 'package:project_lyra/core/cache/cache_key.dart';
import 'package:project_lyra/core/cache/cache_manager.dart';
import 'package:project_lyra/core/cache/memory/memory_cache.dart';
import 'package:project_lyra/core/cache/serialization/cache_serializer.dart';

/// Creates a test-friendly CacheManager with in-memory only storage.
CacheManager createFakeCacheManager() {
  return CacheManager(
    memory: MemoryCache<String>(maxSize: 100),
    disk: FakeDiskCache(),
    serializer: CacheSerializer(),
  );
}

/// Fake disk cache that doesn't persist.
class FakeDiskCache {
  final Map<String, String> _store = {};

  String? get(CacheKey key) => _store[key.value];

  Future<void> put(CacheKey key, String data, {Duration? ttl}) async {
    _store[key.value] = data;
  }

  Future<bool> remove(CacheKey key) async {
    return _store.remove(key.value) != null;
  }

  int get length => _store.length;

  Future<void> clear() async {
    _store.clear();
  }

  bool containsKey(CacheKey key) => _store.containsKey(key.value);
}

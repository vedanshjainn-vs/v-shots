// ════════════════════════════════════════════════
// Project Lyra — Memory Cache Tests
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lyra/core/cache/cache_key.dart';
import 'package:project_lyra/core/cache/memory/memory_cache.dart';

void main() {
  group('MemoryCache', () {
    late MemoryCache<String> cache;

    setUp(() {
      cache = MemoryCache<String>(maxSize: 5);
    });

    test('put and get', () {
      final key = CacheKey.item('tracks', '123');
      cache.put(key, 'Track Data');

      expect(cache.getData(key), 'Track Data');
    });

    test('returns null for missing key', () {
      final key = CacheKey.item('tracks', 'missing');
      expect(cache.getData(key), isNull);
    });

    test('evicts LRU when full', () {
      for (int i = 0; i < 6; i++) {
        cache.put(CacheKey.item('tracks', '$i'), 'Track $i');
      }

      // First item should be evicted.
      expect(cache.getData(CacheKey.item('tracks', '0')), isNull);
      // Last item should still be there.
      expect(cache.getData(CacheKey.item('tracks', '5')), 'Track 5');
    });

    test('accessing an item moves it to front', () {
      for (int i = 0; i < 5; i++) {
        cache.put(CacheKey.item('tracks', '$i'), 'Track $i');
      }

      // Access first item.
      cache.getData(CacheKey.item('tracks', '0'));

      // Add one more to trigger eviction.
      cache.put(CacheKey.item('tracks', '5'), 'Track 5');

      // First item should still be there (accessed recently).
      expect(cache.getData(CacheKey.item('tracks', '0')), 'Track 0');
      // Second item should be evicted.
      expect(cache.getData(CacheKey.item('tracks', '1')), isNull);
    });

    test('remove by namespace', () {
      cache.put(CacheKey.item('tracks', '1'), 'Track 1');
      cache.put(CacheKey.item('tracks', '2'), 'Track 2');
      cache.put(CacheKey.item('albums', '1'), 'Album 1');

      cache.removeByNamespace('tracks');

      expect(cache.getData(CacheKey.item('tracks', '1')), isNull);
      expect(cache.getData(CacheKey.item('tracks', '2')), isNull);
      expect(cache.getData(CacheKey.item('albums', '1')), 'Album 1');
    });

    test('clear removes all entries', () {
      cache.put(CacheKey.item('tracks', '1'), 'Track 1');
      cache.put(CacheKey.item('albums', '1'), 'Album 1');

      cache.clear();

      expect(cache.isEmpty, true);
    });

    test('stats track hits and misses', () {
      final key = CacheKey.item('tracks', '1');
      cache.put(key, 'Track 1');

      cache.getData(key); // hit
      cache.getData(key); // hit
      cache.getData(CacheKey.item('tracks', 'missing')); // miss

      expect(cache.stats.hits, 2);
      expect(cache.stats.misses, 1);
      expect(cache.stats.hitRate, closeTo(0.667, 0.01));
    });
  });
}

// ════════════════════════════════════════════════
// V Shots — SearchCache tests (Phase 11)
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/cache/search_cache.dart';

void main() {
  setUp(SearchCache.instance.clear);

  test('set then get returns the same value', () {
    final tracks = [
      {'id': '1', 'title': 'Song'},
    ];
    SearchCache.instance.set('query', tracks);
    expect(SearchCache.instance.get('query'), tracks);
  });

  test('get returns null for an unknown key', () {
    expect(SearchCache.instance.get('never set'), isNull);
  });

  test('isFresh is true immediately after set, with default TTL', () {
    SearchCache.instance.set('query', const []);
    expect(SearchCache.instance.isFresh('query'), isTrue);
  });

  test('isFresh is false once the TTL has elapsed', () {
    SearchCache.instance.set(
      'query',
      const [],
      ttl: const Duration(milliseconds: -1), // already expired
    );
    expect(SearchCache.instance.isFresh('query'), isFalse);
    // But get() still returns the (stale) value — stale-while-revalidate.
    expect(SearchCache.instance.get('query'), isNotNull);
  });

  test('clear removes all entries', () {
    SearchCache.instance.set('a', const []);
    SearchCache.instance.set('b', const []);
    SearchCache.instance.clear();
    expect(SearchCache.instance.get('a'), isNull);
    expect(SearchCache.instance.get('b'), isNull);
  });
}

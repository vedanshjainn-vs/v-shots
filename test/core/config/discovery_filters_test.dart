// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discovery filter config tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/config/discovery_filters.dart';

void main() {
  group('sources / moods', () {
    test('For You is the personalized (null-query) source', () {
      final forYou = kDiscoverySources.first;
      expect(forYou.id, 'for_you');
      expect(forYou.query, isNull,
          reason: 'For You must use the recommendation-engine path');
    });

    test('every non-personalized source has a distinct, non-empty query', () {
      final queries = kDiscoverySources
          .where((s) => s.query != null)
          .map((s) => s.query)
          .toSet();
      expect(queries.length, kDiscoverySources.length - 1);
      for (final s in kDiscoverySources.where((s) => s.query != null)) {
        expect(s.query!.trim().isNotEmpty, isTrue);
      }
    });

    test('every mood has a distinct, non-empty query', () {
      final queries = kDiscoveryMoods.map((m) => m.query).toSet();
      expect(queries.length, kDiscoveryMoods.length);
    });
  });

  group('buildDiscoveryQuery', () {
    test('source only', () {
      final q = buildDiscoveryQuery(source: kDiscoverySources[1]);
      expect(q, contains('trending'));
      expect(q, isNot(contains('romantic')));
    });

    test('source + mood changes the query', () {
      final trending = kDiscoverySources[1];
      final romantic =
          kDiscoveryMoods.firstWhere((m) => m.id == 'romantic');
      final q = buildDiscoveryQuery(source: trending, mood: romantic);
      expect(q, contains('trending'));
      expect(q, contains('romantic'));
    });

    test('mood alone (For You) yields the mood-biased fallback query', () {
      final sad = kDiscoveryMoods.firstWhere((m) => m.id == 'sad');
      final q = buildDiscoveryQuery(source: kDiscoverySources.first, mood: sad);
      expect(q, contains('sad'));
      expect(q, isNot(contains('trending')));
    });

    test('language + region append their tokens', () {
      final q = buildDiscoveryQuery(
        source: kDiscoverySources[2],
        language: kDiscoveryLanguages.firstWhere((l) => l.id == 'hindi'),
        region: kDiscoveryRegions.firstWhere((r) => r.id == 'bollywood'),
      );
      expect(q, contains('hindi songs'));
      expect(q, contains('bollywood songs'));
    });

    test('selecting a different source produces a different query', () {
      final trending =
          buildDiscoveryQuery(source: kDiscoverySources[1]);
      final viral = buildDiscoveryQuery(source: kDiscoverySources[3]);
      expect(trending, isNot(viral));
    });
  });
}

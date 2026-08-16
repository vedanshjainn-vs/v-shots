// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discovery filter config tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/config/discovery_filters.dart';

void main() {
  group('sources', () {
    test('For You is the personalized (null-query) source', () {
      final forYou = kDiscoverySources.first;
      expect(forYou.id, 'for_you');
      expect(forYou.query, isNull);
    });

    test('every non-personalized source has a distinct query', () {
      final queries = kDiscoverySources
          .where((s) => s.query != null)
          .map((s) => s.query)
          .toSet();
      expect(queries.length, kDiscoverySources.length - 1);
    });

    test('each mode has a distinct ranking order', () {
      final orders = kDiscoverySources.map((s) => s.order).toList();
      expect(orders.toSet(), containsAll(['relevance', 'viewCount', 'date']));
      final trending = kDiscoverySources.firstWhere((s) => s.id == 'trending');
      final latest = kDiscoverySources.firstWhere((s) => s.id == 'latest');
      expect(trending.order, 'viewCount');
      expect(latest.order, 'date');
    });

    test('every mood has a distinct query token', () {
      final tokens = kDiscoveryMoods.map((m) => m.query).toSet();
      expect(tokens.length, kDiscoveryMoods.length);
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
      final romantic = kDiscoveryMoods.firstWhere((m) => m.id == 'romantic');
      final q = buildDiscoveryQuery(source: trending, moods: [romantic]);
      expect(q, contains('trending'));
      expect(q, contains('romantic'));
    });

    test('moods alone (For You) compose a mood-biased query with music intent',
        () {
      final sad = kDiscoveryMoods.firstWhere((m) => m.id == 'sad');
      final q =
          buildDiscoveryQuery(source: kDiscoverySources.first, moods: [sad]);
      expect(q, contains('sad'));
      expect(q, contains('official music'));
    });

    test('multiple languages + regions append their tokens', () {
      final hindi = kDiscoveryLanguages.firstWhere((l) => l.id == 'hindi');
      final english = kDiscoveryLanguages.firstWhere((l) => l.id == 'english');
      final bollywood =
          kDiscoveryRegions.firstWhere((r) => r.id == 'bollywood');
      final q = buildDiscoveryQuery(
        source: kDiscoverySources[2],
        languages: [hindi, english],
        regions: [bollywood],
      );
      expect(q, contains('hindi'));
      expect(q, contains('english'));
      expect(q, contains('bollywood'));
    });

    test('different sources produce different queries', () {
      final trending = buildDiscoveryQuery(source: kDiscoverySources[1]);
      final viral = buildDiscoveryQuery(source: kDiscoverySources[3]);
      expect(trending, isNot(viral));
    });

    test('Romantic + Hindi composes a strongly-constrained query', () {
      final romantic = kDiscoveryMoods.firstWhere((m) => m.id == 'romantic');
      final hindi = kDiscoveryLanguages.firstWhere((l) => l.id == 'hindi');
      final q = buildDiscoveryQuery(
        source: kDiscoverySources.first,
        moods: [romantic],
        languages: [hindi],
      );
      expect(q, contains('romantic'));
      expect(q, contains('hindi'));
      expect(q, contains('official music'));
    });
  });

  group('discoveryFilterSummary', () {
    test('source only shows the source label', () {
      expect(discoveryFilterSummary(source: kDiscoverySources[1]), 'Trending');
    });

    test('mood + language headline the summary', () {
      final romantic = kDiscoveryMoods.firstWhere((m) => m.id == 'romantic');
      final hindi = kDiscoveryLanguages.firstWhere((l) => l.id == 'hindi');
      expect(
        discoveryFilterSummary(
          source: kDiscoverySources.first,
          moods: [romantic],
          languages: [hindi],
        ),
        'Romantic · Hindi',
      );
    });
  });

  group('DiscoveryFilterConfig', () {
    test('matches() detects identical configs', () {
      final a = DiscoveryFilterConfig(
        source: kDiscoverySources[1],
        moods: [],
        languages: [],
        regions: [],
      );
      final b = DiscoveryFilterConfig(
        source: kDiscoverySources[1],
        moods: [],
        languages: [],
        regions: [],
      );
      expect(a.matches(b), isTrue);
    });

    test('matches() differs across sources and filters', () {
      final trending = DiscoveryFilterConfig(source: kDiscoverySources[1]);
      final viral = DiscoveryFilterConfig(source: kDiscoverySources[3]);
      expect(trending.matches(viral), isFalse);

      final romantic = kDiscoveryMoods.firstWhere((m) => m.id == 'romantic');
      final withMood = DiscoveryFilterConfig(
        source: kDiscoverySources.first,
        moods: [romantic],
      );
      expect(DiscoveryFilterConfig.initial.matches(withMood), isFalse);
    });

    test('copyWith preserves unlisted fields', () {
      final base = DiscoveryFilterConfig(source: kDiscoverySources[1]);
      final updated = base.copyWith(source: kDiscoverySources[2]);
      expect(updated.source.id, 'new');
      expect(updated.moods, base.moods);
    });
  });
}

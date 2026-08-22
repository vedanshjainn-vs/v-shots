// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discovery filter config tests (V SHOTS DISCOVER taxonomy)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/config/discovery_filters.dart';

void main() {
  group('V Shots Discover taxonomy (owner spec)', () {
    test('A. Quick Explore has exactly the five specified sources', () {
      expect(
        kDiscoverySources.map((s) => s.label).toList(),
        ['For You', 'Trending', 'New Releases', 'Rising Now', 'Surprise Me'],
      );
    });

    test('B. Browse by Mood has the ten specified moods', () {
      expect(
        kDiscoveryMoods.map((m) => m.label).toList(),
        [
          'Chill',
          'Happy',
          'Sad',
          'Romantic',
          'Energetic',
          'Party',
          'Focus',
          'Sleep',
          'Workout',
          'Devotional',
        ],
      );
    });

    test('C/D/E/F lists match the specified sizes and order anchors', () {
      expect(kDiscoveryLanguages.first.label, 'Hindi');
      expect(kDiscoveryLanguages[1].label, 'Punjabi');
      expect(kDiscoveryLanguages.length, 12);
      expect(
        kDiscoveryGenres.map((g) => g.label).toList(),
        [
          'Bollywood',
          'Indie',
          'Pop',
          'Hip-Hop',
          'EDM',
          'Rock',
          'Lo-Fi',
          'Classical',
          'Ghazal',
          'Sufi',
          'Regional',
        ],
      );
      expect(
        kDiscoveryDecades.map((d) => d.label).toList(),
        ['90s', '2000s', '2010s', '2020s'],
      );
      expect(
        kDiscoveryActivities.map((a) => a.label).toList(),
        [
          'Workout',
          'Road Trip',
          'Late Night',
          'Morning',
          'Party',
          'Study',
          'Travel',
          'Rainy Day',
        ],
      );
    });

    test('For You and Surprise Me are engine sources (null query)', () {
      expect(
        kDiscoverySources.firstWhere((s) => s.id == 'for_you').query,
        isNull,
      );
      expect(
        kDiscoverySources.firstWhere((s) => s.id == 'surprise_me').query,
        isNull,
      );
    });

    test('every non-engine source has a distinct query', () {
      final queries = kDiscoverySources
          .where((s) => s.query != null)
          .map((s) => s.query)
          .toSet();
      expect(queries.length, kDiscoverySources.length - 2);
    });

    test('Rising Now ranks by viewCount', () {
      expect(
        kDiscoverySources.firstWhere((s) => s.id == 'rising_now').order,
        'viewCount',
      );
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

    test(
      'moods alone (For You) compose a mood-biased query with music intent',
      () {
        final sad = kDiscoveryMoods.firstWhere((m) => m.id == 'sad');
        final q = buildDiscoveryQuery(
          source: kDiscoverySources.first,
          moods: [sad],
        );
        expect(q, contains('sad'));
        expect(q, contains('official music'));
      },
    );

    test('languages + genres + decades + activities append their tokens', () {
      final hindi = kDiscoveryLanguages.firstWhere((l) => l.id == 'hindi');
      final bollywood = kDiscoveryGenres.firstWhere((g) => g.id == 'bollywood');
      final nineties = kDiscoveryDecades.first;
      final workout = kDiscoveryActivities.first;
      final q = buildDiscoveryQuery(
        source: kDiscoverySources[2],
        languages: [hindi],
        genres: [bollywood],
        decades: [nineties],
        activities: [workout],
      );
      expect(q, contains('hindi'));
      expect(q, contains('bollywood'));
      expect(q, contains('90s hits'));
      expect(q, contains('workout'));
    });

    test('different sources produce different queries', () {
      final trending = buildDiscoveryQuery(source: kDiscoverySources[1]);
      final rising = buildDiscoveryQuery(source: kDiscoverySources[3]);
      expect(trending, isNot(rising));
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
        moods: const [],
        languages: const [],
        genres: const [],
        decades: const [],
        activities: const [],
      );
      final b = DiscoveryFilterConfig(
        source: kDiscoverySources[1],
        moods: const [],
        languages: const [],
        genres: const [],
        decades: const [],
        activities: const [],
      );
      expect(a.matches(b), isTrue);
    });

    test('matches() differs across sources and filters', () {
      final trending = DiscoveryFilterConfig(source: kDiscoverySources[1]);
      final rising = DiscoveryFilterConfig(source: kDiscoverySources[3]);
      expect(trending.matches(rising), isFalse);

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
      expect(updated.decades, base.decades);
    });
  });
}

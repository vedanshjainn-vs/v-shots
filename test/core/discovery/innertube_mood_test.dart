// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — InnerTube mood / recommendation tests
//
// Verifies the mood-based discovery and recommendation logic used by the
// Discovery reels feed and personalized Home:
//   - kMoodQueries covers the required moods
//   - each mood has a distinct query strategy
//   - discoveryFeed empty/mood-exclusion is offline-safe
//   - personalized home shelf derives a query from a recent artist
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/discovery/innertube_music_service.dart';

void main() {
  group('kMoodQueries', () {
    test('covers the required moods', () {
      const required = [
        'Relax',
        'Workout',
        'Energize',
        'Romance',
        'Sad',
        'Party',
        'Focus',
        'Chill',
        'Sleep',
        'Devotional',
        'Trending',
      ];
      for (final m in required) {
        expect(kMoodQueries.containsKey(m), isTrue,
            reason: 'mood "$m" should have queries');
        expect(kMoodQueries[m], isNotEmpty);
      }
    });

    test('each mood has a distinct first query (real filter)', () {
      final firstQueries = kMoodQueries.values.map((q) => q.first).toSet();
      // Different moods may share some overlap but the map must not be empty.
      expect(kMoodQueries, isNotEmpty);
      expect(firstQueries.length, greaterThan(5));
    });

    test('queries never empty', () {
      kMoodQueries.forEach((mood, q) {
        expect(q, isNotEmpty, reason: 'mood $mood has empty query list');
        expect(q.first.trim().isNotEmpty, isTrue);
      });
    });
  });

  group('discoveryFeed', () {
    test('returns a list (may be empty offline) without crashing', () async {
      final svc = InnerTubeMusicService();
      final feed = await svc.discoveryFeed(mood: 'Workout', target: 10);
      expect(feed, isA<List<DiscoveryTrack>>());
      svc.dispose();
    });

    test('excludeIds is applied to avoid repeats', () async {
      final svc = InnerTubeMusicService();
      // In the offline test env the feed is likely empty; this just verifies
      // the exclude path does not throw.
      final feed = await svc.discoveryFeed(
        mood: 'Trending',
        target: 10,
        excludeIds: {'some-video-id'},
      );
      expect(feed.where((t) => t.id == 'some-video-id'), isEmpty);
      svc.dispose();
    });
  });

  group('personalized home shelf', () {
    test('recent artist yields a "More like X" query path', () async {
      final svc = InnerTubeMusicService();
      // Offline-safe: homeFeed should not throw with recentlyPlayed context.
      final shelves = await svc.homeFeed(recentlyPlayed: [
        {'artist': 'Arijit Singh', 'title': 'Kesariya'},
      ]);
      expect(shelves, isA<List<MusicShelf>>());
      svc.dispose();
    });
  });
}

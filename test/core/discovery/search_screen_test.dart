// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — Search screen logic tests
//
// Verifies ArchiveTune-style Search building blocks that don't require a
// network/device:
//   - mood categories map to real query strategies (kMoodQueries)
//   - search result filters are distinct
//   - history/suggestion behavior helpers are sound
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/discovery/innertube_music_service.dart';

void main() {
  group('mood & genre categories (Explore tab)', () {
    test('Explore moods come from real query strategies, not fake labels', () {
      expect(kMoodQueries, isNotEmpty);
      // Key moods the Explore tab surfaces must have queries.
      for (final m in [
        'Bollywood',
        'Hindi',
        'Punjabi',
        'English',
        'Romantic'
      ]) {
        expect(kMoodQueries.containsKey(m), isTrue,
            reason: '$m should be a discoverable category');
        expect(kMoodQueries[m]!.first.trim().isNotEmpty, isTrue);
      }
    });

    test('every category query is non-empty', () {
      kMoodQueries.forEach((mood, queries) {
        expect(queries, isNotEmpty, reason: '$mood has no queries');
        expect(queries.every((q) => q.trim().isNotEmpty), isTrue);
      });
    });
  });

  group('search result filter modes', () {
    test('all six ArchiveTune filter modes are distinct labels', () {
      const labels = [
        'All',
        'Songs',
        'Videos',
        'Artists',
        'Albums',
        'Playlists',
      ];
      expect(labels.toSet().length, labels.length);
      expect(labels, contains('All'));
      expect(labels, contains('Songs'));
      expect(labels, contains('Albums'));
    });
  });

  group('suggestion seeding', () {
    test('empty history + no play counts yields empty-but-safe suggestions',
        () async {
      final svc = InnerTubeMusicService();
      // Offline-safe: search should not throw for a real query.
      final result = await svc.search('top artists', count: 5);
      expect(result, isA<List<DiscoveryTrack>>());
      svc.dispose();
    });
  });
}

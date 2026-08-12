// ═════════════════════════════════════════════════════════════════════════
// V Shots — Discover Deduplication & Artist-Repetition Tests (Phase 9)
//
// Verifies the feed's dedupe policy: no duplicate video IDs, and a max of 2
// consecutive tracks from the same artist. Mirrors the logic in
// for_you_feed_screen.dart (_dedupeBatch) so we can test it in isolation.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';

class _Deduper {
  final Set<String> seenIds = {};
  final Set<String> seenArtists = {};
  static const int maxConsecutive = 2;
  String? lastArtist;
  int lastRun = 0;

  List<Map<String, dynamic>> dedupe(List<Map<String, dynamic>> batch) {
    final out = <Map<String, dynamic>>[];
    for (final t in batch) {
      final id = t['id'] as String? ?? '';
      final artist = t['artist'] as String? ?? '';
      if (id.isEmpty || seenIds.contains(id)) continue;
      if (artist == lastArtist && lastRun >= maxConsecutive) continue;
      seenIds.add(id);
      if (artist.isNotEmpty) seenArtists.add(artist);
      if (artist == lastArtist) {
        lastRun++;
      } else {
        lastArtist = artist;
        lastRun = 1;
      }
      out.add(t);
    }
    return out;
  }
}

void main() {
  group('Discover dedup (Phase 9)', () {
    test('rejects duplicate video IDs within a batch', () {
      final d = _Deduper();
      final out = d.dedupe([
        {'id': 'a', 'artist': 'X'},
        {'id': 'a', 'artist': 'X'},
        {'id': 'b', 'artist': 'Y'},
      ]);
      expect(out.map((t) => t['id']).toList(), ['a', 'b']);
    });

    test('rejects duplicate video IDs across batches', () {
      final d = _Deduper();
      d.dedupe([
        {'id': 'a', 'artist': 'X'}
      ]);
      final out = d.dedupe([
        {'id': 'a', 'artist': 'X'},
        {'id': 'c', 'artist': 'Z'}
      ]);
      expect(out.map((t) => t['id']).toList(), ['c']);
    });

    test('limits to 2 consecutive tracks from the same artist', () {
      final d = _Deduper();
      final out = d.dedupe([
        {'id': '1', 'artist': 'A'},
        {'id': '2', 'artist': 'A'},
        {'id': '3', 'artist': 'A'},
        {'id': '4', 'artist': 'B'},
      ]);
      // Third A should be rejected; B accepted.
      expect(out.map((t) => t['id']).toList(), ['1', '2', '4']);
    });

    test('allows artist again after a different artist breaks the run', () {
      final d = _Deduper();
      final out = d.dedupe([
        {'id': '1', 'artist': 'A'},
        {'id': '2', 'artist': 'A'},
        {'id': '3', 'artist': 'B'},
        {'id': '4', 'artist': 'A'},
      ]);
      expect(out.map((t) => t['id']).toList(), ['1', '2', '3', '4']);
    });
  });
}

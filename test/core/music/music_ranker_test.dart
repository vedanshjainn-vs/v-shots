// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicRanker tests (mode strategies + diversity + penalties)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/music/music_ranker.dart';

Map<String, dynamic> _t(String id, String artist, {int views = 0, int? age}) =>
    {
      'id': id,
      'title': 'T $id',
      'artist': artist,
      'views': views,
      if (age != null) 'ageDays': age,
    };

void main() {
  const ranker = MusicRanker();

  group('mode strategies are genuinely different', () {
    test('popular sorts by views desc', () {
      final r = ranker.rankPopular([
        _t('a', 'X', views: 100),
        _t('b', 'Y', views: 500),
        _t('c', 'Z', views: 300),
      ]);
      expect(r.map((t) => t['id']).toList(), ['b', 'c', 'a']);
    });

    test('trending prefers RECENT high views over old high views', () {
      final recent = _t('recent', 'X', views: 1000, age: 2);
      final old = _t('old', 'Y', views: 1500, age: 365);
      final r = ranker.rankTrending([old, recent]);
      expect(
        r.first['id'],
        'recent',
        reason: 'a 2-year-old high-view song must not beat a fresh one',
      );
    });

    test('newest sorts by age ascending, unknown last', () {
      final r = ranker.rankNewest([
        _t('old', 'X', age: 30),
        _t('new', 'Y', age: 2),
        _t('unknown', 'Z'),
      ]);
      expect(r.map((t) => t['id']).toList(), ['new', 'old', 'unknown']);
    });

    test('viral uses velocity (views / age)', () {
      final fast = _t('fast', 'X', views: 100, age: 1);
      final slow = _t('slow', 'Y', views: 1000, age: 100);
      final r = ranker.rankViral([slow, fast]);
      expect(r.first['id'], 'fast');
    });

    test('missing views/age preserve original order (no fabrication)', () {
      final r = ranker.rankPopular([_t('a', 'X'), _t('b', 'Y'), _t('c', 'Z')]);
      expect(r.map((t) => t['id']).toList(), ['a', 'b', 'c']);
    });
  });

  group('diversity / penalties / exploration', () {
    test('applyDiversity caps per-artist', () {
      final r = ranker.applyDiversity([
        _t('1', 'A'),
        _t('2', 'A'),
        _t('3', 'A'),
        _t('4', 'A'),
        _t('5', 'B'),
      ]);
      final aCount = r.where((t) => t['artist'] == 'A').length;
      expect(aCount, 3);
    });

    test(
      'applyAlreadySeenPenalty moves seen items to the end (never drops)',
      () {
        final r = ranker.applyAlreadySeenPenalty(
          [_t('a', 'X'), _t('b', 'Y'), _t('c', 'Z')],
          {'b'},
        );
        expect(r.map((t) => t['id']).toList(), ['a', 'c', 'b']);
      },
    );

    test('mixExploration interleaves exploration at the configured ratio', () {
      final primary = List.generate(8, (i) => _t('p$i', 'A'));
      final exploration = [_t('e0', 'E'), _t('e1', 'E')];
      final r = ranker.mixExploration(primary, exploration, ratio: 0.25);
      expect(r.where((t) => (t['id'] as String).startsWith('e')).length, 2);
      // Exploration items never at the very front.
      expect((r.first['id'] as String).startsWith('p'), isTrue);
    });

    test('mixExploration no-ops on empty exploration', () {
      final primary = [_t('p0', 'A')];
      expect(ranker.mixExploration(primary, []), primary);
    });
  });
}

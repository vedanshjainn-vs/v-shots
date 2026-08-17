// ═════════════════════════════════════════════════════════════════════════════
// V Shots — VShotsPlaybackManager auto-advance tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/playback/vshots_playback_manager.dart';

Map<String, dynamic> _t(String id) => {
      'id': id,
      'title': 'T $id',
      'artist': 'A',
      'artwork': 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      'duration': 200,
    };

void main() {
  final mgr = VShotsPlaybackManager.instance;

  setUp(mgr.close);

  group('auto-advance (onVideoEnded)', () {
    test('advances exactly once to the next queue item (repeat off)', () {
      mgr.playQueue([_t('a'), _t('b'), _t('c')], 0);
      expect(mgr.currentTrack?['id'], 'a');

      mgr.onVideoEnded('a');
      expect(mgr.currentTrack?['id'], 'b');

      // Duplicate completion events for the SAME video are ignored.
      mgr.onVideoEnded('a');
      mgr.onVideoEnded('a');
      expect(mgr.currentTrack?['id'], 'b');
    });

    test('stops at the end of the queue (repeat off, no shuffle)', () {
      mgr.playQueue([_t('a'), _t('b')], 1);
      mgr.onVideoEnded('b'); // b completed → end of queue
      expect(mgr.currentTrack?['id'], 'b',
          reason: 'repeat off must not wrap past the queue end');
    });

    test('repeat all wraps to the first item', () {
      mgr.playQueue([_t('a'), _t('b')], 1);
      mgr.setRepeat(PlaybackRepeat.all);
      mgr.onVideoEnded('b');
      expect(mgr.currentTrack?['id'], 'a');
    });

    test('repeat one replays the same track (replay request fired)', () {
      mgr.playQueue([_t('a'), _t('b')], 0);
      mgr.setRepeat(PlaybackRepeat.one);
      final before = mgr.browser.replayRequest.value;
      mgr.onVideoEnded('a');
      expect(mgr.currentTrack?['id'], 'a',
          reason: 'repeat one keeps the same track');
      expect(mgr.browser.replayRequest.value, before + 1,
          reason: 'repeat one must request a reload of the same URL');
    });

    test('shuffle ON advances via the shuffle order', () {
      mgr.playQueue([_t('a'), _t('b'), _t('c'), _t('d')], 0);
      mgr.toggleShuffle();
      final order = mgr.shuffleOrder; // current kept first at [0]
      expect(order.first, 0);
      mgr.onVideoEnded('a');
      expect(mgr.currentIndex, order[1],
          reason: 'auto-advance must follow shuffle order');
    });

    test('manual next() after completion continues cleanly', () {
      mgr.playQueue([_t('a'), _t('b'), _t('c')], 0);
      mgr.onVideoEnded('a');
      expect(mgr.currentTrack?['id'], 'b');
      mgr.next();
      expect(mgr.currentTrack?['id'], 'c');
      mgr.onVideoEnded('c'); // c completes → end
      mgr.onVideoEnded('c'); // duplicate ignored
      expect(mgr.currentTrack?['id'], 'c');
    });
  });
}

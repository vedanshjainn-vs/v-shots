// ═════════════════════════════════════════════════════════════════════════
// V Shots — PlaybackManager Tests (Phase 1)
//
// Verifies the formal PlaybackManager wraps the single global engine and
// exposes correct queue/next/previous/state behavior WITHOUT creating a second
// player.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/player/playback_manager.dart';

void main() {
  group('PlaybackManager', () {
    test('play() sets current track and queue index', () {
      final pm = PlaybackManager.instance;
      final tracks = [
        {'id': 'a', 'title': 'A'},
        {'id': 'b', 'title': 'B'},
      ];
      pm.play(track: tracks[1], queue: tracks, index: 1);
      expect(pm.currentTrack?['id'], 'b');
      expect(pm.queueIndex, 1);
    });

    test('next() advances and previous() goes back within queue', () {
      final pm = PlaybackManager.instance;
      final tracks = [
        {'id': 'a', 'title': 'A'},
        {'id': 'b', 'title': 'B'},
        {'id': 'c', 'title': 'C'},
      ];
      pm.play(track: tracks[0], queue: tracks, index: 0);
      pm.next();
      expect(pm.currentTrack?['id'], 'b');
      pm.next();
      expect(pm.currentTrack?['id'], 'c');
      pm.previous();
      expect(pm.currentTrack?['id'], 'b');
    });

    test('enqueue() appends tracks to the live queue', () {
      final pm = PlaybackManager.instance;
      pm.play(
        track: {'id': 'x', 'title': 'X'},
        queue: [
          {'id': 'x', 'title': 'X'},
        ],
        index: 0,
      );
      pm.enqueue([
        {'id': 'y', 'title': 'Y'},
      ]);
      expect(pm.queue.length, 2);
      expect(pm.nextInQueue?['id'], 'y');
    });

    test('next() wraps to first when at end of queue', () {
      final pm = PlaybackManager.instance;
      final tracks = [
        {'id': 'a', 'title': 'A'},
        {'id': 'b', 'title': 'B'},
      ];
      pm.play(track: tracks[1], queue: tracks, index: 1);
      pm.next();
      expect(pm.currentTrack?['id'], 'a');
    });

    test('handleVideoEnded advances within queue', () {
      final pm = PlaybackManager.instance;
      final tracks = [
        {'id': 'a', 'title': 'A'},
        {'id': 'b', 'title': 'B'},
      ];
      pm.play(track: tracks[0], queue: tracks, index: 0);
      pm.handleVideoEnded();
      expect(pm.currentTrack?['id'], 'b');
    });
  });
}

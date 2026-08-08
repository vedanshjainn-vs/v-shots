// ════════════════════════════════════════════════
// Project Lyra — Playback Queue Tests
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lyra/core/media/queue/playback_queue.dart';
import 'package:project_lyra/core/media/state/playback_models.dart';

void main() {
  final tracks = List.generate(
    5,
    (i) => QueueItem(
      id: 'track_$i',
      title: 'Track $i',
      artist: 'Artist $i',
      duration: Duration(minutes: 3 + i),
    ),
  );

  group('PlaybackQueue', () {
    test('initializes with tracks', () {
      final queue = PlaybackQueue(tracks: tracks);

      expect(queue.length, 5);
      expect(queue.current?.id, 'track_0');
    });

    test('next advances to next track', () {
      var queue = PlaybackQueue(tracks: tracks);

      queue = queue.next();
      expect(queue.currentIndex, 1);
      expect(queue.current?.id, 'track_1');
    });

    test('previous goes back', () {
      var queue = PlaybackQueue(tracks: tracks, currentIndex: 2);

      queue = queue.previous();
      expect(queue.currentIndex, 1);
    });

    test('next stops at end without repeat', () {
      var queue = PlaybackQueue(tracks: tracks, currentIndex: 4);

      queue = queue.next();
      expect(queue.currentIndex, 4);
    });

    test('next wraps with repeat all', () {
      var queue = PlaybackQueue(
        tracks: tracks,
        currentIndex: 4,
        repeatMode: RepeatMode.all,
      );

      queue = queue.next();
      expect(queue.currentIndex, 0);
    });

    test('repeat one stays on same track', () {
      var queue = PlaybackQueue(
        tracks: tracks,
        currentIndex: 2,
        repeatMode: RepeatMode.one,
      );

      queue = queue.next();
      expect(queue.currentIndex, 2);
    });

    test('add appends track', () {
      var queue = PlaybackQueue(tracks: tracks);

      queue = queue.add(QueueItem(id: 'new', title: 'New', artist: 'A'));

      expect(queue.length, 6);
    });

    test('insertNext adds after current', () {
      var queue = PlaybackQueue(tracks: tracks, currentIndex: 1);

      queue = queue.insertNext(QueueItem(id: 'new', title: 'New', artist: 'A'));

      expect(queue.length, 6);
      expect(queue.tracks[2].id, 'new');
    });

    test('removeAt removes track', () {
      var queue = PlaybackQueue(tracks: tracks);

      queue = queue.removeAt(0);

      expect(queue.length, 4);
      expect(queue.tracks[0].id, 'track_1');
    });

    test('jumpTo changes index', () {
      var queue = PlaybackQueue(tracks: tracks);

      queue = queue.jumpTo(3);

      expect(queue.currentIndex, 3);
      expect(queue.current?.id, 'track_3');
    });

    test('setRepeatMode changes mode', () {
      var queue = PlaybackQueue(tracks: tracks);

      queue = queue.setRepeatMode(RepeatMode.all);

      expect(queue.repeatMode, RepeatMode.all);
    });

    test('toggleShuffle toggles shuffle', () {
      var queue = PlaybackQueue(tracks: tracks);

      queue = queue.toggleShuffle();

      expect(queue.shuffleEnabled, true);
    });

    test('hasNext returns true when not at end', () {
      final queue = PlaybackQueue(tracks: tracks, currentIndex: 2);

      expect(queue.hasNext, true);
    });

    test('hasNext returns false at end without repeat', () {
      final queue = PlaybackQueue(tracks: tracks, currentIndex: 4);

      expect(queue.hasNext, false);
    });

    test('hasPrevious returns true when not at start', () {
      final queue = PlaybackQueue(tracks: tracks, currentIndex: 2);

      expect(queue.hasPrevious, true);
    });

    test('hasPrevious returns false at start without repeat', () {
      final queue = PlaybackQueue(tracks: tracks, currentIndex: 0);

      expect(queue.hasPrevious, false);
    });
  });
}

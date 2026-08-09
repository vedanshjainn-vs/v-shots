// ════════════════════════════════════════════════
// V Shots — QueueController tests (Phase 8/11: Shuffle + Repeat logic)
// ════════════════════════════════════════════════
//
// Tests ONLY the pure, parameterized `computeSkip`/`computeCompletion`
// methods (no dependency on main.dart's globals) — these are exactly
// the functions the app's real global-queue wrappers
// (nextIndexForSkip/nextIndexOnCompletion) and PlayerScreen's local
// _next()/_prev() both delegate to, so testing them here covers the
// real logic without needing to import main.dart (which would pull in
// the whole app's widget tree) or fake global state.
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/player/queue_controller.dart';
import 'package:v_shots/core/player/repeat_mode.dart';

void main() {
  group('computeSkip (explicit next/previous)', () {
    test('non-shuffle: wraps forward past the end', () {
      final next = QueueController.computeSkip(
        queueLength: 3,
        currentIndex: 2,
        delta: 1,
        shuffleOn: false,
        order: const [],
      );
      expect(next, 0);
    });

    test('non-shuffle: wraps backward past the start', () {
      final prev = QueueController.computeSkip(
        queueLength: 3,
        currentIndex: 0,
        delta: -1,
        shuffleOn: false,
        order: const [],
      );
      expect(prev, 2);
    });

    test('shuffle: follows the shuffle order, not natural queue order', () {
      // Shuffle order says: play index 2, then 0, then 1.
      const order = [2, 0, 1];
      final next = QueueController.computeSkip(
        queueLength: 3,
        currentIndex: 2, // currently at position 0 in shuffle order
        delta: 1,
        shuffleOn: true,
        order: order,
      );
      expect(next, 0); // position 1 in shuffle order
    });

    test('shuffle: wraps around the shuffle order at the end', () {
      const order = [2, 0, 1];
      final next = QueueController.computeSkip(
        queueLength: 3,
        currentIndex: 1, // last position in shuffle order
        delta: 1,
        shuffleOn: true,
        order: order,
      );
      expect(next, 2); // wraps to first position in shuffle order
    });

    test('always wraps regardless of repeat mode (explicit skip)', () {
      // This test documents the deliberate design: computeSkip takes
      // no RepeatMode parameter at all — an explicit skip always
      // moves, matching every real music app's behavior even when
      // Repeat is off.
      final next = QueueController.computeSkip(
        queueLength: 1,
        currentIndex: 0,
        delta: 1,
        shuffleOn: false,
        order: const [],
      );
      expect(next, 0); // single-item queue wraps to itself
    });
  });

  group('computeCompletion (natural track-finish, respects repeat mode)', () {
    test('RepeatMode.one always replays the current index', () {
      final result = QueueController.computeCompletion(
        queueLength: 5,
        currentIndex: 2,
        mode: RepeatMode.one,
        shuffleOn: false,
        order: const [],
      );
      expect(result.index, 2);
      expect(result.rebuildShuffle, isFalse);
    });

    test('RepeatMode.off advances normally mid-queue', () {
      final result = QueueController.computeCompletion(
        queueLength: 5,
        currentIndex: 1,
        mode: RepeatMode.off,
        shuffleOn: false,
        order: const [],
      );
      expect(result.index, 2);
    });

    test('RepeatMode.off stops (null) at the natural end of the queue', () {
      final result = QueueController.computeCompletion(
        queueLength: 3,
        currentIndex: 2, // last index
        mode: RepeatMode.off,
        shuffleOn: false,
        order: const [],
      );
      expect(result.index, isNull);
      expect(result.rebuildShuffle, isFalse);
    });

    test('RepeatMode.all wraps back to index 0 at the end (no shuffle)', () {
      final result = QueueController.computeCompletion(
        queueLength: 3,
        currentIndex: 2,
        mode: RepeatMode.all,
        shuffleOn: false,
        order: const [],
      );
      expect(result.index, 0);
    });

    test('RepeatMode.off + shuffle stops at the end of the shuffle order', () {
      const order = [2, 0, 1];
      final result = QueueController.computeCompletion(
        queueLength: 3,
        currentIndex: 1, // last position in shuffle order
        mode: RepeatMode.off,
        shuffleOn: true,
        order: order,
      );
      expect(result.index, isNull);
    });

    test('RepeatMode.all + shuffle signals a fresh shuffle at the end', () {
      const order = [2, 0, 1];
      final result = QueueController.computeCompletion(
        queueLength: 3,
        currentIndex: 1, // last position in shuffle order
        mode: RepeatMode.all,
        shuffleOn: true,
        order: order,
      );
      // At the end of a shuffled lap with repeat-all, the caller is
      // told to build a fresh shuffle rather than given a fixed next
      // index directly (see queue_controller.dart's doc comment).
      expect(result.rebuildShuffle, isTrue);
    });

    test('empty queue returns null with no rebuild', () {
      final result = QueueController.computeCompletion(
        queueLength: 0,
        currentIndex: 0,
        mode: RepeatMode.all,
        shuffleOn: false,
        order: const [],
      );
      expect(result.index, isNull);
      expect(result.rebuildShuffle, isFalse);
    });
  });

  group('RepeatMode.next() cycles off -> one -> all -> off', () {
    test('cycles through all three states', () {
      expect(RepeatMode.off.next(), RepeatMode.one);
      expect(RepeatMode.one.next(), RepeatMode.all);
      expect(RepeatMode.all.next(), RepeatMode.off);
    });
  });
}

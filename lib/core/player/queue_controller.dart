// ════════════════════════════════════════════════
// V Shots — Queue navigation logic (shuffle + repeat), Phase 8 fix
// ════════════════════════════════════════════════
//
// WHY THIS FILE EXISTS:
// Before this, "what plays next" was a single hardcoded line in
// main.dart's `_playAdjacentInQueue()`:
//   (currentQueueIndex + delta + currentQueue.length) % currentQueue.length
// — always the natural queue order, wrapping unconditionally, with no
// way to express "play in shuffled order" or "stop instead of wrapping
// because repeat is off." This file is the ONE place that decides the
// next index to play, for both:
//   - an explicit user/OS skip (next/previous button, headset button)
//     — see [nextIndexForSkip], which always moves regardless of
//     repeat mode (skipping while "Repeat One" is on should still
//     skip — that matches every real music app's behavior; repeat-one
//     only changes what happens when a track finishes ON ITS OWN).
//   - a track finishing playback naturally — see
//     [nextIndexOnCompletion], which DOES respect repeat mode
//     (off/one/all).
//
// DESIGN — parameterized, not hardcoded to the globals: the core logic
// (`_computeSkip`/`_computeCompletion`) takes queueLength/currentIndex
// explicitly so both main.dart's global-queue skip path AND
// PlayerScreen's local `widget.queue`/`_currentIndex` (a separate
// local copy the existing PlayerScreen code already used before this
// task — see PlayerScreen._next()/._prev()) can share the exact same
// shuffle/repeat rules without one of them silently using different
// logic. The convenience wrappers below operate on the app's existing
// global state (`currentQueue`, `currentQueueIndex`, `isShuffleOn`,
// `shuffleOrder`, `repeatMode`) for call sites that use the globals
// directly (`_playAdjacentInQueue`, `_handleTrackCompleted`).
// ════════════════════════════════════════════════

import 'dart:math';

import '../../main.dart' show
    currentQueue,
    currentQueueIndex,
    isShuffleOn,
    repeatMode,
    shuffleOrder;
import 'repeat_mode.dart';

class QueueController {
  QueueController._();

  static final Random _random = Random();

  /// Builds a fresh shuffled permutation of `currentQueue`'s indices
  /// into the global `shuffleOrder` list. If [keepCurrentAt] is given
  /// (the index currently playing), it's placed FIRST in the new
  /// order — so turning shuffle on mid-playback doesn't immediately
  /// jump away from the track the user is currently listening to; the
  /// shuffle only affects what plays *after* it.
  static void rebuildShuffleOrder({int? keepCurrentAt}) {
    if (currentQueue.isEmpty) {
      shuffleOrder = [];
      return;
    }
    final indices = List<int>.generate(currentQueue.length, (i) => i);
    indices.shuffle(_random);
    if (keepCurrentAt != null && indices.remove(keepCurrentAt)) {
      indices.insert(0, keepCurrentAt);
    }
    shuffleOrder = indices;
  }

  static void _ensureShuffleOrderValid() {
    if (shuffleOrder.length != currentQueue.length) {
      rebuildShuffleOrder(keepCurrentAt: currentQueueIndex);
    }
  }

  /// The queue index to play for an explicit skip (next: delta=+1,
  /// previous: delta=-1) against the app's GLOBAL queue state. Always
  /// wraps, regardless of repeat mode. Returns null if the queue is
  /// empty. See [computeSkip] for the parameterized/testable version
  /// this delegates to.
  static int? nextIndexForSkip(int delta) {
    if (currentQueue.isEmpty) return null;
    if (isShuffleOn) _ensureShuffleOrderValid();
    return computeSkip(
      queueLength: currentQueue.length,
      currentIndex: currentQueueIndex,
      delta: delta,
      shuffleOn: isShuffleOn,
      order: shuffleOrder,
    );
  }

  /// The queue index to play when the CURRENT track finishes on its
  /// own, against the app's GLOBAL queue state. See [computeCompletion]
  /// for the parameterized/testable version this delegates to.
  static int? nextIndexOnCompletion() {
    if (currentQueue.isEmpty) return null;
    if (isShuffleOn) _ensureShuffleOrderValid();
    final result = computeCompletion(
      queueLength: currentQueue.length,
      currentIndex: currentQueueIndex,
      mode: repeatMode,
      shuffleOn: isShuffleOn,
      order: shuffleOrder,
    );
    if (result.rebuildShuffle) {
      rebuildShuffleOrder(); // fresh shuffle for the next lap
      // Re-resolve against the freshly rebuilt order.
      return shuffleOrder.isEmpty ? null : shuffleOrder.first;
    }
    return result.index;
  }

  /// Pure, parameterized skip computation — always wraps regardless of
  /// [mode]/repeat (an explicit skip is a deliberate user/OS action).
  /// Exposed as a static method (not private) so PlayerScreen's local
  /// `widget.queue`/`_currentIndex` skip logic and unit tests can both
  /// use the exact same rule as the global-queue path above, without a
  /// second, potentially-drifting copy of this arithmetic.
  static int computeSkip({
    required int queueLength,
    required int currentIndex,
    required int delta,
    required bool shuffleOn,
    required List<int> order,
  }) {
    if (!shuffleOn || order.length != queueLength) {
      return (currentIndex + delta + queueLength) % queueLength;
    }
    final pos = order.indexOf(currentIndex);
    final safePos = pos == -1 ? 0 : pos;
    final nextPos = (safePos + delta + order.length) % order.length;
    return order[nextPos];
  }

  /// Pure, parameterized completion computation. `rebuildShuffle` in
  /// the result means "shuffle+repeat-all reached the end of a lap —
  /// caller should build a fresh shuffle order and start from its
  /// first entry" (queue_controller's global wrapper above does this;
  /// a caller using this directly for a local queue copy should do the
  /// equivalent).
  static ({int? index, bool rebuildShuffle}) computeCompletion({
    required int queueLength,
    required int currentIndex,
    required RepeatMode mode,
    required bool shuffleOn,
    required List<int> order,
  }) {
    if (queueLength == 0) return (index: null, rebuildShuffle: false);

    if (mode == RepeatMode.one) {
      return (index: currentIndex, rebuildShuffle: false);
    }

    if (!shuffleOn || order.length != queueLength) {
      final isLast = currentIndex >= queueLength - 1;
      if (isLast) {
        return mode == RepeatMode.all
            ? (index: 0, rebuildShuffle: false)
            : (index: null, rebuildShuffle: false);
      }
      return (index: currentIndex + 1, rebuildShuffle: false);
    }

    final pos = order.indexOf(currentIndex);
    final safePos = pos == -1 ? 0 : pos;
    final isLast = safePos >= order.length - 1;
    if (isLast) {
      if (mode != RepeatMode.all) {
        return (index: null, rebuildShuffle: false);
      }
      return (index: null, rebuildShuffle: true);
    }
    return (index: order[safePos + 1], rebuildShuffle: false);
  }
}

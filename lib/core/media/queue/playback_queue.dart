// ════════════════════════════════════════════════
// Project Lyra — Playback Queue
// ════════════════════════════════════════════════
//
// Manages the playback queue with support for:
// - Next/previous navigation
// - Shuffle mode
// - Repeat modes
// - Queue manipulation (add, remove, reorder)
// - Queue persistence
// ════════════════════════════════════════════════

import 'dart:math';

import '../state/playback_models.dart';

/// Manages the playback queue.
///
/// Supports shuffle, repeat, and queue manipulation.
/// Immutable operations — returns new queue states.
///
/// ```dart
/// var queue = PlaybackQueue(tracks: tracks);
/// queue = queue.next();
/// queue = queue.toggleShuffle();
/// queue = queue.setRepeatMode(RepeatMode.all);
/// ```
class PlaybackQueue {
  PlaybackQueue({
    required this.tracks,
    this.currentIndex = 0,
    this.repeatMode = RepeatMode.off,
    this.shuffleEnabled = false,
    List<int>? shuffleOrder,
  }) : _shuffleOrder = shuffleOrder ?? _generateShuffleOrder(tracks.length);

  final List<QueueItem> tracks;
  final int currentIndex;
  final RepeatMode repeatMode;
  final bool shuffleEnabled;
  final List<int> _shuffleOrder;
  final _random = Random();

  /// Current track.
  QueueItem? get current =>
      tracks.isNotEmpty ? tracks[_effectiveIndex(currentIndex)] : null;

  /// Total number of tracks.
  int get length => tracks.length;

  /// Whether the queue is empty.
  bool get isEmpty => tracks.isEmpty;

  /// Whether there is a next track.
  bool get hasNext {
    if (isEmpty) return false;
    if (repeatMode == RepeatMode.all || repeatMode == RepeatMode.one) return true;
    return currentIndex < length - 1;
  }

  /// Whether there is a previous track.
  bool get hasPrevious {
    if (isEmpty) return false;
    if (repeatMode == RepeatMode.all) return true;
    return currentIndex > 0;
  }

  /// Get the effective index (accounting for shuffle).
  int _effectiveIndex(int index) {
    if (shuffleEnabled && _shuffleOrder.isNotEmpty) {
      return _shuffleOrder[index % _shuffleOrder.length];
    }
    return index;
  }

  /// Move to the next track.
  PlaybackQueue next() {
    if (isEmpty) return this;

    if (repeatMode == RepeatMode.one) {
      return PlaybackQueue(
        tracks: tracks,
        currentIndex: currentIndex,
        repeatMode: repeatMode,
        shuffleEnabled: shuffleEnabled,
        shuffleOrder: _shuffleOrder,
      );
    }

    int nextIndex = currentIndex + 1;

    if (nextIndex >= length) {
      if (repeatMode == RepeatMode.all) {
        nextIndex = 0;
      } else {
        return this; // End of queue.
      }
    }

    return PlaybackQueue(
      tracks: tracks,
      currentIndex: nextIndex,
      repeatMode: repeatMode,
      shuffleEnabled: shuffleEnabled,
      shuffleOrder: _shuffleOrder,
    );
  }

  /// Move to the previous track.
  PlaybackQueue previous() {
    if (isEmpty) return this;

    int prevIndex = currentIndex - 1;

    if (prevIndex < 0) {
      if (repeatMode == RepeatMode.all) {
        prevIndex = length - 1;
      } else {
        prevIndex = 0;
      }
    }

    return PlaybackQueue(
      tracks: tracks,
      currentIndex: prevIndex,
      repeatMode: repeatMode,
      shuffleEnabled: shuffleEnabled,
      shuffleOrder: _shuffleOrder,
    );
  }

  /// Jump to a specific index.
  PlaybackQueue jumpTo(int index) {
    if (index < 0 || index >= length) return this;
    return PlaybackQueue(
      tracks: tracks,
      currentIndex: index,
      repeatMode: repeatMode,
      shuffleEnabled: shuffleEnabled,
      shuffleOrder: _shuffleOrder,
    );
  }

  /// Add a track to the queue.
  PlaybackQueue add(QueueItem item) {
    return PlaybackQueue(
      tracks: [...tracks, item],
      currentIndex: currentIndex,
      repeatMode: repeatMode,
      shuffleEnabled: shuffleEnabled,
    );
  }

  /// Insert a track after the current track.
  PlaybackQueue insertNext(QueueItem item) {
    final newTracks = List<QueueItem>.from(tracks);
    final insertAt = (currentIndex + 1).clamp(0, newTracks.length);
    newTracks.insert(insertAt, item);

    return PlaybackQueue(
      tracks: newTracks,
      currentIndex: currentIndex,
      repeatMode: repeatMode,
      shuffleEnabled: shuffleEnabled,
    );
  }

  /// Remove a track at index.
  PlaybackQueue removeAt(int index) {
    if (index < 0 || index >= length) return this;

    final newTracks = List<QueueItem>.from(tracks)..removeAt(index);
    int newIndex = currentIndex;
    if (index < currentIndex) {
      newIndex = currentIndex - 1;
    } else if (index == currentIndex && currentIndex >= newTracks.length) {
      newIndex = newTracks.length - 1;
    }

    return PlaybackQueue(
      tracks: newTracks,
      currentIndex: newIndex.clamp(0, newTracks.length - 1),
      repeatMode: repeatMode,
      shuffleEnabled: shuffleEnabled,
    );
  }

  /// Reorder tracks.
  PlaybackQueue reorder(int oldIndex, int newIndex) {
    final newTracks = List<QueueItem>.from(tracks);
    final item = newTracks.removeAt(oldIndex);
    newTracks.insert(newIndex, item);

    int adjustedCurrent = currentIndex;
    if (oldIndex == currentIndex) {
      adjustedCurrent = newIndex;
    }

    return PlaybackQueue(
      tracks: newTracks,
      currentIndex: adjustedCurrent,
      repeatMode: repeatMode,
      shuffleEnabled: shuffleEnabled,
    );
  }

  /// Toggle shuffle mode.
  PlaybackQueue toggleShuffle() {
    return PlaybackQueue(
      tracks: tracks,
      currentIndex: currentIndex,
      repeatMode: repeatMode,
      shuffleEnabled: !shuffleEnabled,
    );
  }

  /// Set repeat mode.
  PlaybackQueue setRepeatMode(RepeatMode mode) {
    return PlaybackQueue(
      tracks: tracks,
      currentIndex: currentIndex,
      repeatMode: mode,
      shuffleEnabled: shuffleEnabled,
      shuffleOrder: _shuffleOrder,
    );
  }

  /// Clear the queue.
  PlaybackQueue clear() {
    return PlaybackQueue(tracks: []);
  }

  /// Replace the entire queue.
  PlaybackQueue replace(List<QueueItem> newTracks, {int startIndex = 0}) {
    return PlaybackQueue(
      tracks: newTracks,
      currentIndex: startIndex,
      repeatMode: repeatMode,
      shuffleEnabled: shuffleEnabled,
    );
  }

  static List<int> _generateShuffleOrder(int length) {
    final order = List.generate(length, (i) => i);
    order.shuffle();
    return order;
  }
}

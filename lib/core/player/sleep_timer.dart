// ════════════════════════════════════════════════
// V Shots — Sleep Timer (global, app-wide)
// ════════════════════════════════════════════════
//
// A single, app-wide sleep timer — not per-screen — so starting it from
// the Player screen and starting it from the "For You" feed's more-
// options sheet both control the SAME timer (there is only one
// `audioPlayer` in this app; a second, competing timer implementation
// would be a real bug, not a feature).
//
// Exposed as a ValueNotifier<Duration?> (null = no timer running) so
// any widget can show a live countdown via ValueListenableBuilder
// without plumbing state through parent widgets.
// ════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../main.dart' show audioPlayer;
import '../playback/vshots_playback_manager.dart';

class SleepTimer {
  SleepTimer._();
  static final SleepTimer instance = SleepTimer._();

  final ValueNotifier<Duration?> remaining = ValueNotifier(null);

  Timer? _ticker;
  DateTime? _endsAt;

  bool get isActive => remaining.value != null;

  /// Starts (or replaces) the timer to pause playback after [duration].
  void start(Duration duration) {
    _ticker?.cancel();
    _endsAt = DateTime.now().add(duration);
    remaining.value = duration;

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _endsAt!.difference(DateTime.now());
      if (left.isNegative || left == Duration.zero) {
        _fire();
        return;
      }
      remaining.value = left;
    });
  }

  /// Extends an already-running timer by [extra] — used by the
  /// "+10 min" style quick-adjust some UIs offer; also safe to call
  /// with no timer running (starts a fresh one).
  void extend(Duration extra) {
    final left = remaining.value ?? Duration.zero;
    start(left + extra);
  }

  void cancel() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    remaining.value = null;
  }

  void _fire() {
    audioPlayer.pause();
    cancel();
  }
}

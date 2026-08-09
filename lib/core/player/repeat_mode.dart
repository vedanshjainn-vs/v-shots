// ════════════════════════════════════════════════
// V Shots — Repeat mode state (Phase 8 fix)
// ════════════════════════════════════════════════
//
// WHY THIS FILE EXISTS:
// The audit confirmed PlayerScreen's Repeat button was a real, empty
// `onPressed: () {}` stub with zero backing state anywhere in the
// codebase. This is that state — a plain 3-value enum, not a bool,
// because "repeat" genuinely has three distinct real behaviors users
// expect (off / repeat the current track forever / repeat the whole
// queue), and collapsing that into a bool would either drop a real
// mode or require a second bool anyway.
// ════════════════════════════════════════════════

enum RepeatMode {
  /// No repeat — queue plays through once, then stops at the last
  /// track (auto-advance still moves forward normally until then).
  off,

  /// The current track repeats indefinitely — skip next/previous still
  /// works (an explicit user action), but track *completion* replays
  /// the same track instead of advancing.
  one,

  /// The whole queue loops — after the last track completes, playback
  /// wraps back to the first track instead of stopping.
  all;

  RepeatMode next() {
    switch (this) {
      case RepeatMode.off:
        return RepeatMode.one;
      case RepeatMode.one:
        return RepeatMode.all;
      case RepeatMode.all:
        return RepeatMode.off;
    }
  }
}

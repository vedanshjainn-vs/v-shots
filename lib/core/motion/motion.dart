// ════════════════════════════════════════════════
// V Shots — Motion System (Phase 7, Part C)
// ════════════════════════════════════════════════
//
// WHY THIS FILE EXISTS:
// Before this, the app had zero shared animation infrastructure — no
// custom AnimationController anywhere, no shared durations/curves, no
// reusable transition widgets (confirmed via `grep -rln
// "AnimationController" lib/` returning zero matches pre-Phase-7).
// Any future animation work would have started from scratch each
// time, risking exactly what the task explicitly forbids: "scattered
// random AnimationController implementations everywhere."
//
// This file is the ONE place motion constants and reusable
// implicit-animation helpers live. Per the task's own research
// takeaway (Flutter's own guidance: prefer implicit animations —
// AnimatedContainer/AnimatedOpacity/TweenAnimationBuilder — for ~80%
// of UI animation needs, reserve AnimationController for
// loops/gestures/complex choreography), everything here is built on
// Flutter's implicit animation widgets wherever possible, which also
// means: no manual dispose() burden, no risk of controller leaks, and
// automatic interruption-handling if a value changes mid-animation.
//
// DESIGN PRINCIPLE (per the task): FAST, SUBTLE, PREMIUM, CONSISTENT.
// Durations below are deliberately short (120-320ms) — long animations
// on a personal music app read as sluggish, not premium. Curves favor
// `Curves.easeOutCubic`/`Curves.easeOut` (fast start, gentle stop) —
// the same curve family already used by the one pre-existing
// transition in this app (MainShell._openPlayer's PageRouteBuilder,
// which already used Curves.easeOutCubic before this task — kept
// consistent with that established choice rather than introducing a
// different feel).
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Shared motion tokens — the ONE source of truth for animation timing
/// across the app. Change a value here, and every screen using
/// `AppMotion.*` picks it up consistently instead of N screens each
/// hardcoding their own duration.
class AppMotion {
  AppMotion._();

  // ── Durations ──────────────────────────────────────────────────
  /// Micro-interactions: button press, like-heart pop, icon morphs.
  /// Fast enough to feel instant/responsive to a tap.
  static const Duration micro = Duration(milliseconds: 120);

  /// Standard content transitions: fade-ins, card press feedback,
  /// skeleton-to-content swaps, mini-player appearance.
  static const Duration fast = Duration(milliseconds: 220);

  /// Larger transitions: page routes, mini-player <-> full player,
  /// staggered list entrances' total span.
  static const Duration medium = Duration(milliseconds: 320);

  // ── Curves ─────────────────────────────────────────────────────
  /// Default curve for most entrances — fast start, gentle settle.
  /// Matches the curve already used by the app's one pre-existing
  /// custom transition (_openPlayer's PageRouteBuilder).
  static const Curve enter = Curves.easeOutCubic;

  /// Default curve for exits/dismissals — mirrors [enter] for
  /// visual symmetry (an element should leave the way it arrived).
  static const Curve exit = Curves.easeInCubic;

  /// For playful, springy micro-interactions (like button, play
  /// button press) — a little overshoot reads as "premium," not
  /// "laggy," specifically because it's paired with [micro]'s short
  /// duration.
  static const Curve springy = Curves.easeOutBack;

  /// Respects the OS-level "reduce motion" accessibility setting
  /// (`MediaQuery.disableAnimations`) — per this task's own researched
  /// Flutter best practice ("respect accessibility... respect
  /// disableAnimations preference"). Returns [Duration.zero] when the
  /// user has reduced motion enabled, so every widget using this
  /// helper degrades to an instant state-change instead of forcing an
  /// animation on users who've explicitly opted out of them.
  static Duration effectiveDuration(BuildContext context, Duration base) {
    return MediaQuery.of(context).disableAnimations ? Duration.zero : base;
  }
}

/// A staggered fade+slide entrance for list/grid items — the shared
/// implementation for "staggered list entrance" (Part C requirement).
/// Wrap each item in a horizontally/vertically scrolling list with
/// this, passing that item's index; items later in the list start
/// their animation slightly later, producing a cascading reveal
/// without a manual AnimationController per item.
///
/// Deliberately capped ([maxStaggerIndex]) so a long list doesn't make
/// the LAST visible item wait multiple seconds to appear — beyond that
/// index, every item animates at the same (small) delay. This is what
/// keeps the effect feeling "alive but not slow," per Part D's
/// explicit instruction.
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    required this.index,
    required this.child,
    super.key,
    this.maxStaggerIndex = 6,
    this.perItemDelay = const Duration(milliseconds: 40),
  });

  final int index;
  final Widget child;
  final int maxStaggerIndex;
  final Duration perItemDelay;

  @override
  Widget build(BuildContext context) {
    final effectiveIndex = index.clamp(0, maxStaggerIndex);
    final delayMs = effectiveIndex * perItemDelay.inMilliseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.fast + Duration(milliseconds: delayMs),
      curve: Interval(
        (delayMs / (AppMotion.fast.inMilliseconds + delayMs)).clamp(0.0, 0.9),
        1.0,
        curve: AppMotion.enter,
      ),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            // Small vertical rise (12px), not a large slide — "subtle"
            // per the task's own requirement, not a showy effect.
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Fade+scale entrance for artwork — used wherever a network image
/// should "pop in" gently once loaded rather than appearing instantly
/// (AppImage already has its own 200ms cross-fade for the
/// cached_network_image transition itself; this wraps a fully-loaded
/// artwork widget for an additional subtle scale-in on first build,
/// e.g. the Player screen's large artwork).
class ArtworkFadeIn extends StatelessWidget {
  const ArtworkFadeIn({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: AppMotion.medium,
      curve: AppMotion.enter,
      builder: (context, scale, child) => Opacity(
        opacity: ((scale - 0.92) / 0.08).clamp(0.0, 1.0),
        child: Transform.scale(scale: scale, child: child),
      ),
      child: child,
    );
  }
}

/// Press-feedback wrapper — the shared "card press" / "button press"
/// micro-interaction (Part C requirement). Scales the child down
/// slightly on press-down and back up on release, with a fast, springy
/// curve. Used for Home cards, Search result tiles, and anywhere a
/// tap target benefits from tactile visual feedback beyond the
/// existing `HapticFeedback` calls already in the app.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    required this.onTap,
    super.key,
    this.pressedScale = 0.96,
  });

  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: AppMotion.micro,
        curve: AppMotion.springy,
        child: widget.child,
      ),
    );
  }
}

/// Shared like-button "pop" animation — plays once whenever [liked]
/// flips from false to true (does NOT play when un-liking, matching
/// the real-world convention of "liking" being the celebratory action,
/// "unliking" being a plain, un-celebrated state change).
class LikePop extends StatefulWidget {
  const LikePop({required this.liked, required this.child, super.key});

  final bool liked;
  final Widget child;

  @override
  State<LikePop> createState() => _LikePopState();
}

class _LikePopState extends State<LikePop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // An explicit AnimationController IS justified here (per the
    // task's own guidance: implicit animations for simple cases,
    // explicit for choreography) — this needs a one-shot
    // forward-then-back sequence (a TweenSequence), which
    // AnimatedScale alone cannot express as a single triggered "pop."
    _controller =
        AnimationController(vsync: this, duration: AppMotion.micro * 2);
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: AppMotion.springy));
  }

  @override
  void didUpdateWidget(LikePop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.liked && !oldWidget.liked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      // `child` is built ONCE and reused every frame (per the task's
      // own researched Flutter best practice: "pass a child to
      // AnimatedBuilder so the expensive subtree is built once") —
      // widget.child here is typically just an Icon, cheap either way,
      // but this is the correct pattern regardless of cost.
      builder: (context, child) =>
          Transform.scale(scale: _scale.value, child: child),
      child: widget.child,
    );
  }
}

/// Shared play/pause icon "morph" — a simple, fast cross-fade+scale
/// between the two icon states, used by the mini-player, full player,
/// and Discover feed's play/pause indicator so all three feel
/// identical rather than each screen inventing its own transition (or,
/// as before, using zero transition — a bare `Icon(isPlaying ? pause :
/// play)` swap with no animation at all).
class PlayPauseMorph extends StatelessWidget {
  const PlayPauseMorph({
    required this.isPlaying,
    super.key,
    this.size = 32,
    this.color,
  });

  final bool isPlaying;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.micro,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Icon(
        isPlaying ? Icons.pause : Icons.play_arrow,
        // A distinct Key per state is required for AnimatedSwitcher to
        // detect the change and animate it (see this file's research
        // notes on AnimatedSwitcher's key-based diffing).
        key: ValueKey(isPlaying),
        size: size,
        color: color,
      ),
    );
  }
}

/// Shared skeleton-to-content cross-fade — wraps a skeleton/shimmer
/// widget and its real content, cross-fading between them based on
/// [showContent]. Used by Home sections (and reusable anywhere else
/// a loading->loaded transition should feel like a soft cross-fade
/// instead of an abrupt swap.
class SkeletonToContent extends StatelessWidget {
  const SkeletonToContent({
    required this.showContent,
    required this.skeleton,
    required this.content,
    super.key,
  });

  final bool showContent;
  final Widget skeleton;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      child: showContent
          ? KeyedSubtree(key: const ValueKey('content'), child: content)
          : KeyedSubtree(key: const ValueKey('skeleton'), child: skeleton),
    );
  }
}

/// Shared mini-player slide-up/down — an `AnimatedSlide` +
/// `AnimatedOpacity` combo so the mini-player eases in/out instead of
/// simply appearing/disappearing via a conditional `if` in a `Stack`
/// (which is what MainShell did before Phase 7 — a bare `if
/// (currentTrack != null && _index != 1) Positioned(...)` with no
/// transition at all).
class MiniPlayerTransition extends StatelessWidget {
  const MiniPlayerTransition(
      {required this.visible, required this.child, super.key});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.effectiveDuration(context, AppMotion.fast);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: duration,
        curve: visible ? AppMotion.enter : AppMotion.exit,
        offset: visible ? Offset.zero : const Offset(0, 0.3),
        child: AnimatedOpacity(
          duration: duration,
          curve: visible ? AppMotion.enter : AppMotion.exit,
          opacity: visible ? 1 : 0,
          child: child,
        ),
      ),
    );
  }
}

/// Shared page-transition builder for `PageRouteBuilder` — a fade+
/// slight-slide-up, consistent with the one pre-existing custom
/// transition in this app (MainShell._openPlayer). Exposed here so
/// FUTURE new full-screen pushes (e.g. Settings, Legal docs, Help) can
/// reuse the exact same feel instead of each falling back to Flutter's
/// default platform transition (an inconsistency that existed before
/// this file: `_openPlayer` had a custom transition, but
/// `MaterialPageRoute` pushes elsewhere — Library, Playlists, Lyrics,
/// Settings — used the plain platform default).
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: AppMotion.medium,
          reverseTransitionDuration: AppMotion.fast,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved =
                CurvedAnimation(parent: animation, curve: AppMotion.enter);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

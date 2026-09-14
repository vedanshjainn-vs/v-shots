import 'dart:async';
import 'dart:ui' as ui;

// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discovery in-app YouTube browser (mini player + expandable sheet)
// ═════════════════════════════════════════════════════════════════════════════
//
// Discovery-scoped browser that opens the OFFICIAL YouTube watch page
// (https://www.youtube.com/watch?v=<id>) inside the app — the real YouTube
// web content, never a fake player. States:
//   collapsed  → a compact glass mini player above the bottom navigation
//   expanded   → browser bar (minimize / lock+URL / close) over the live page
//
// Extent is driven by a single AnimationController (0=collapsed .. 1=expanded)
// so the collapse/expand gesture is finger-connected and deterministic — no
// DraggableScrollableSheet quirks. Drag on the mini player or the browser bar
// updates the extent; release snaps to collapsed/expanded (with a midpoint
// snap).
//
// The native Android browser view is created ONCE per session and stays
// mounted, at a CONSTANT size, while collapsed — collapse/expand only
// TRANSLATE the browser layer, never resizing or detaching the playback view.
// Closing disposes the session.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:share_plus/share_plus.dart';

import '../../core/browser/vshots_content_blocker.dart';
import '../../core/motion/motion.dart';
import '../../core/playback/vshots_playback_manager.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/animated_equalizer.dart';
import '../../shared/widgets/app_image.dart';
import '../../main.dart'
    show LyricsScreen, playbackSignalTracker, showAddToPlaylistSheet;
import 'discovery_browser_controller.dart';
import 'vshots_browser_session.dart';
import 'vshots_playback_state.dart';

class DiscoveryBrowserSheet extends StatefulWidget {
  const DiscoveryBrowserSheet({super.key, required this.controller});

  final DiscoveryBrowserController controller;

  @override
  State<DiscoveryBrowserSheet> createState() => _DiscoveryBrowserSheetState();
}

class _DiscoveryBrowserSheetState extends State<DiscoveryBrowserSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _extent;
  late final VShotsBrowserSession _session;
  String? _lastLoadedUrl;
  String? _lastNotificationTrackId;
  bool _isSeeking = false;
  double? _seekPreviewMs;
  bool _audioCommandInFlight = false;

  /// Rebuilds the shield indicator when the blocker is toggled.
  final ValueNotifier<int> _blockerRefresh = ValueNotifier<int>(0);

  static const double _miniHeight = 84;
  static const double _maxFraction = 0.92;
  static const double _halfFraction = 0.55;

  @override
  void initState() {
    super.initState();
    _extent = AnimationController(
      vsync: this,
      value: widget.controller.startExpanded ? 1.0 : 0.0,
    );
    _extent.addListener(_onExtentTick);
    widget.controller.addListener(_onControllerChanged);
    widget.controller.extentCommand.addListener(_onExtentCommand);
    widget.controller.replayRequest.addListener(_onReplayRequest);
    widget.controller.pauseRequest.addListener(_onPauseRequest);
    widget.controller.togglePlaybackRequest.addListener(
      _onTogglePlaybackRequest,
    );
    // The single browser session: owns the native WebView + lifecycle; the
    // sheet is only the UI/interaction layer. Minimizing never destroys the
    // session.
    _session = VShotsBrowserSession(
      onPageStarted: () => widget.controller.setLoading(true),
      onPageFinished: () => widget.controller.setLoading(false),
      onPlaybackState: widget.controller.setPagePlaying,
      onPlaybackStateChanged: widget.controller.setPlaybackState,
      onError: _onPrimaryPageError,
      // Real media completion (native `video.ended`) → auto-advance the queue
      // through the single global manager (screen on AND screen off).
      onVideoEnded: (id) {
        final current =
            VShotsPlaybackManager.instance.currentTrack?['id'] as String? ?? '';
        VShotsPlaybackManager.instance.onVideoEnded(
          id.isNotEmpty ? id : current,
        );
      },
      // In-stream ad start/end from the native WebView → "Ad" badge in the
      // player UI (mute/skip/resume is handled natively).
      onAdState: (on) => widget.controller.setAdActive(on),
      onAudioState: widget.controller.setAudioState,
      onPosition: widget.controller.setPosition,
      onNotificationAction: (action) async {
        switch (action) {
          case 'play':
            // Precise commands (media session + audio focus) — never a
            // blind toggle: a focus GAIN must not double-toggle.
            await _session.play();
            break;
          case 'pause':
            await _session.pause();
            break;
          case 'focusPause':
            await _session.pause(userInitiated: false);
            break;
          case 'focusPlay':
            await _session.play(userInitiated: false);
            break;
          case 'duckOn':
            // A transient sound (navigation prompt, notification) is
            // speaking — duck to 15% instead of stopping the music.
            await _session.setVolume(0.15);
            break;
          case 'duckOff':
            await _session.setVolume(1.0);
            break;
          case 'next':
            VShotsPlaybackManager.instance.next();
            break;
          case 'previous':
            VShotsPlaybackManager.instance.previous();
            break;
          case 'rewind':
            await _session.seekBy(-10);
            break;
          case 'fastForward':
            await _session.seekBy(10);
            break;
          case 'stop':
            _close();
            break;
        }
      },
      // Player-essential hosts are ALWAYS allowed, so the general content
      // blocker can never break video/audio/thumbnail delivery.
      contentBlocker: VShotsContentBlocker(
        essentialHosts: const [
          'youtube.com',
          'youtu.be',
          'googlevideo.com',
          'ytimg.com',
          'gstatic.com',
          'ggpht.com',
          'google.com',
          'googleapis.com',
          'jiosaavn.com',
          'www.jiosaavn.com',
          'static.saavncdn.com',
          'c.saavncdn.com',
        ],
      ),
    );
    _loadForCurrent();
    // Sync the controller's expanded flag with the initial extent AFTER the
    // first frame (setState can't run during initState).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.setExpanded(_extent.value > 0.55);
    });
  }

  @override
  void dispose() {
    widget.controller.pauseRequest.removeListener(_onPauseRequest);
    widget.controller.togglePlaybackRequest.removeListener(
      _onTogglePlaybackRequest,
    );
    widget.controller.replayRequest.removeListener(_onReplayRequest);
    widget.controller.extentCommand.removeListener(_onExtentCommand);
    widget.controller.removeListener(_onControllerChanged);
    _extent.dispose();
    _blockerRefresh.dispose();
    _session.dispose();
    super.dispose();
  }

  void _onExtentCommand() {
    final command = widget.controller.extentCommand.value;
    widget.controller.extentCommand.value = 0;
    if (command == 1) {
      _animateTo(0.0);
    } else if (command == 2) {
      _animateTo(1.0);
    }
  }

  /// Repeat-one: reload the CURRENT url in the same session (the native
  /// layer resets its per-load ended flag, so the next completion fires
  /// again). No new WebView.
  void _onPauseRequest() {
    unawaited(_session.pause());
  }

  void _onTogglePlaybackRequest() {
    unawaited(_togglePagePlayback());
  }

  void _onReplayRequest() {
    unawaited(_session.retry());
    widget.controller.setLoading(true);
    widget.controller.setError(null);
  }

  void _onExtentTick() {
    widget.controller.setExpanded(_extent.value > 0.55);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (!widget.controller.isOpen) return;
    final url = widget.controller.url;
    if (url != null && url != _lastLoadedUrl) {
      // Video switched: collapse back to the mini player and reload.
      _extent.value = 0.0;
      _loadForCurrent();
    }
    setState(() {});
  }

  // ── Extent gesture (finger-connected with snap) ─────────────────────────

  /// Cumulative downward drag distance for the CURRENT gesture — used so a
  /// deliberate pull-down closes the browser even when the release velocity
  /// is low (drag-then-hold, or a slow but firm swipe).
  double _downPixels = 0;

  /// Whether THIS gesture began while the player was EXPANDED. The close
  /// gesture is only valid from the MINIMIZED state: a downward swipe from
  /// EXPANDED always minimizes (never closes), fixing the reported bug.
  bool _startedExpanded = false;

  void _onDragStart(DragStartDetails details) {
    _downPixels = 0;
    _startedExpanded = _extent.value > 0.5;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0) _downPixels += details.delta.dy;
    final maxH = MediaQuery.of(context).size.height * _maxFraction;
    final travel = maxH - _miniHeight;
    if (travel <= 0) return;
    final delta = -details.delta.dy / travel;
    _extent.value = (_extent.value + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    // Dismiss is ONLY valid when the gesture started from MINIMIZED. A
    // deliberate downward fling OR a firm downward pull then closes the
    // browser. From EXPANDED, a downward swipe always minimizes — never
    // closes (state-machine bug fix). Tiny taps/noise never reach this.
    final fastDownFling = velocity > 450;
    final firmDownPull = _downPixels > 80;
    if (!_startedExpanded &&
        (fastDownFling || firmDownPull) &&
        _extent.value < 0.25) {
      _close();
      return;
    }
    if (velocity < -800) {
      _animateTo(1.0); // fling up → full
      return;
    }
    if (velocity > 800) {
      _animateTo(0.0); // fling down → collapse
      return;
    }
    // Velocity-neutral: snap to the nearest of collapsed / half / full.
    if (_extent.value > 0.75) {
      _animateTo(1.0);
    } else if (_extent.value > 0.35) {
      _animateTo(_halfFraction);
    } else {
      _animateTo(0.0);
    }
  }

  void _animateTo(double target) {
    _extent.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  // ── Browser session ─────────────────────────────────────────────────────

  bool _usedFallback = false;

  void _onPrimaryPageError(String message) {
    final track = widget.controller.track;
    final fallback = track?['fallbackUrl'] as String?;
    if (!_usedFallback &&
        fallback != null &&
        fallback.isNotEmpty &&
        fallback != _lastLoadedUrl) {
      _usedFallback = true;
      _lastLoadedUrl = fallback;
      widget.controller.setLoading(true);
      widget.controller.setError(null);
      _session.load(fallback);
      return;
    }
    widget.controller.setLoading(false);
    widget.controller.setError(message);
  }

  Future<void> _loadForCurrent() async {
    final url = widget.controller.url;
    if (url == null) return;
    _usedFallback = false;
    _lastLoadedUrl = url;
    widget.controller.setLoading(true);
    widget.controller.setError(null);
    widget.controller.setPagePlaying(null);

    // Native load first clears the previous media state. Metadata is then
    // published as metadata only; it can never turn an unknown/loading page
    // into PLAYING or request audio focus.
    await _session.load(url);
    final notificationTrackId = widget.controller.track?['id']?.toString();
    if (_lastNotificationTrackId != notificationTrackId) {
      _lastNotificationTrackId = notificationTrackId;
      unawaited(
        _session.updateNotification(
          title: widget.controller.title ?? 'V Shots',
          artist: widget.controller.artist ?? 'Music playback',
          artwork: widget.controller.artwork ?? '',
          playing: false,
        ),
      );
    }
  }

  Future<void> _togglePagePlayback() async {
    // Translate the UI gesture into an explicit platform command. The native
    // state event will update the controller; the optimistic assignment is
    // only a fallback for old platform views without state events.
    final before = widget.controller.pagePlaying;
    final result = await _session.togglePagePlayback();
    if (result == null) {
      if (before == true) {
        await _session.pause();
      } else {
        await _session.play();
      }
      return;
    }
    widget.controller.setPagePlaying(result);
  }

  void _close() {
    _extent
        .animateTo(
      0.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeIn,
    )
        .then((_) {
      if (mounted) VShotsPlaybackManager.instance.close();
    });
  }

  Future<void> _enableAudio() async {
    if (_audioCommandInFlight) return;
    _audioCommandInFlight = true;
    await HapticFeedback.lightImpact();
    try {
      // This is an explicit user command. It is not a toggle: native playback
      // owns the generation guard and performs the already-validated trusted
      // YouTube unmute path before synchronizing the media element.
      await _session.play();
    } finally {
      if (mounted) setState(() => _audioCommandInFlight = false);
    }
  }

  void _openQueueSheet() {
    final manager = VShotsPlaybackManager.instance;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (sheetContext) => AnimatedBuilder(
        animation: manager,
        builder: (context, _) => _PremiumQueueSheet(
          queue: manager.queue,
          currentIndex: manager.currentIndex,
          onSelect: (index) {
            manager.jumpTo(index);
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
  }

  String _formatTime(int milliseconds) {
    final totalSeconds = (milliseconds / 1000).floor().clamp(0, 24 * 60 * 60);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _audioLabel() {
    return switch (widget.controller.audioState) {
      VShotsAudioState.playingWithAudio => 'Audio on',
      VShotsAudioState.playingMutedContent => 'Sound is off',
      VShotsAudioState.playingMutedAd => 'Ad muted',
      VShotsAudioState.buffering => 'Buffering',
      VShotsAudioState.paused => 'Paused',
      VShotsAudioState.ended => 'Ended',
      VShotsAudioState.error => 'Playback error',
      VShotsAudioState.idle => 'Ready',
    };
  }

  // ── Build ────────────────────────────────────────────────────────────────
  //
  // CRITICAL LIFECYCLE GUARANTEE: the native browser view is laid out at a
  // CONSTANT full height (maxH) at all times and is only TRANSLATED when
  // collapsed. It is never resized, clipped-to-tiny, or detached — the mini
  // player is pure chrome ON TOP of the still-alive browser.
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final maxH = screenH * _maxFraction;
    return AnimatedBuilder(
      animation: _extent,
      builder: (context, _) {
        final e = _extent.value;
        final collapseOffset = (1 - e) * (maxH - _miniHeight);
        return ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: maxH,
                child: IgnorePointer(
                  ignoring: e < 0.5,
                  child: Transform.translate(
                    offset: Offset(0, collapseOffset),
                    child: Column(
                      children: [
                        Opacity(
                          opacity: e.clamp(0.0, 1.0),
                          child: _buildBrowserBar(),
                        ),
                        Expanded(child: _buildBrowserBody()),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: IgnorePointer(
                  ignoring: e > 0.5,
                  child: Opacity(
                    opacity: (1 - e * 2).clamp(0.0, 1.0),
                    child: _buildMiniPlayer(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Expanded browser bar ─────────────────────────────────────────────────

  Widget _buildBrowserBar() {
    final title = widget.controller.title ?? 'V Shots Player';
    final track = widget.controller.track;
    return GestureDetector(
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.background.withValues(alpha: 0.9),
                  AppColors.surface.withValues(alpha: 0.72),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: MediaQuery.of(context).padding.top + 4,
              bottom: 6,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textMain,
                    size: 29,
                  ),
                  tooltip: 'Minimize player',
                  onPressed: () => _animateTo(0.0),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NOW PLAYING',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMain,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: _blockerRefresh,
                  builder: (context, _, __) {
                    final on = _session.contentBlocker.enabled;
                    return IconButton(
                      icon: Icon(
                        on ? Icons.shield_rounded : Icons.shield_outlined,
                        color: on ? AppColors.accent : AppColors.textSubtle,
                        size: 20,
                      ),
                      tooltip: on ? 'Ad blocking on' : 'Ad blocking off',
                      onPressed: () async {
                        await _session.contentBlocker.setEnabled(!on);
                        await _session.applyContentBlocker();
                        _blockerRefresh.value++;
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'More options',
                  onPressed:
                      track == null ? null : () => _openPlayerActions(track),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMain,
                    size: 22,
                  ),
                  tooltip: 'Close player',
                  onPressed: _close,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _displayUrl() {
    final url = widget.controller.url ?? '';
    if (url.isEmpty) return '';
    return url.replaceFirst(RegExp(r'^https://'), '');
  }

  // ── Collapsed mini player ────────────────────────────────────────────────

  Widget _buildMiniPlayer() {
    final title = widget.controller.title ?? 'Playing video';
    final artist = widget.controller.artist ?? '';
    final artwork = widget.controller.artwork;
    final playing = widget.controller.pagePlaying == true;
    final progress = widget.controller.progress;

    return GestureDetector(
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      onTap: () => _animateTo(1.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xF51A1A2B), Color(0xF00B0E18)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.16,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: AppImage(artwork, fit: BoxFit.cover),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: FractionallySizedBox(
                  widthFactor: progress <= 0 ? 0.0 : progress,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: AppColors.accentGradient,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          ArtworkFadeIn(
                            child: AppImage(
                              artwork,
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorIconColor: AppColors.accent,
                            ),
                          ),
                          if (widget.controller.isLoading)
                            const Positioned.fill(
                              child: ColoredBox(
                                color: Color(0x99000000),
                                child: Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (playing)
                            const Positioned(
                              left: 5,
                              bottom: 5,
                              child: AnimatedEqualizer(
                                size: 14,
                                color: AppColors.accent,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textMain,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (widget.controller.adActive) ...[
                                const SizedBox(width: 6),
                                const _AdBadge(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _audioLabel(),
                            style: TextStyle(
                              color: widget.controller.audioState ==
                                      VShotsAudioState.playingMutedContent
                                  ? AppColors.warning
                                  : AppColors.textSubtle,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: AnimatedSwitcher(
                        duration: AppMotion.micro,
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          key: ValueKey<bool>(playing),
                          color: AppColors.textMain,
                          size: 28,
                        ),
                      ),
                      tooltip: playing ? 'Pause' : 'Play',
                      onPressed: _togglePagePlayback,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: AppColors.textSecondary,
                        size: 25,
                      ),
                      tooltip: 'Open player',
                      onPressed: () => _animateTo(1.0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Expanded body (native browser / loading / error) ────────────────────

  Widget _buildBrowserBody() {
    if (widget.controller.error != null) return _buildError();
    final artwork = widget.controller.artwork;
    final audioMuted =
        widget.controller.audioState == VShotsAudioState.playingMutedContent;
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // A restrained artwork wash keeps the player cinematic without
              // touching the native WebView's persistent layout or lifecycle.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: AppColors.background),
                  child: Opacity(
                    opacity: 0.28,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                      child: AppImage(artwork, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.background.withValues(alpha: 0.25),
                        AppColors.background.withValues(alpha: 0.88),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: _session.buildWidget(),
                  ),
                ),
              ),
              if (widget.controller.isLoading) const _PremiumLoadingOverlay(),
              if (audioMuted && !widget.controller.adActive)
                Positioned.fill(
                  child: Center(
                    child: _SoundPrompt(
                      busy: _audioCommandInFlight,
                      onPressed: _enableAudio,
                    ),
                  ),
                ),
              if (widget.controller.playbackState ==
                      VShotsPlaybackState.buffering &&
                  !widget.controller.isLoading)
                const Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: _StatusPill(
                    icon: Icons.hourglass_top_rounded,
                    label: 'Buffering',
                  ),
                ),
            ],
          ),
        ),
        // V Shots full-player chrome: metadata + controls + queue. Rendered
        // only when expanded (the mini player covers the collapsed state).
        if (_extent.value > 0.5) _buildExpandedControls(),
      ],
    );
  }

  void _openPlayerLyrics() {
    final track = widget.controller.track;
    if (track == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.72,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: LyricsScreen(track: track),
        ),
      ),
    );
  }

  /// The app-level full-player controls over the WebView engine. The real
  /// YouTube page provides its own seek bar; V Shots adds queue control
  /// (prev/next/shuffle/repeat), like, playlist, lyrics and share.
  Widget _buildExpandedControls() {
    final manager = VShotsPlaybackManager.instance;
    final track = widget.controller.track ?? const <String, dynamic>{};
    final title = (track['title'] as String?) ?? 'Unknown track';
    final artist = (track['artist'] as String?) ?? 'V Shots';
    final trackId = (track['id'] as String?) ?? '';
    final isLiked =
        trackId.isNotEmpty && LocalLibrary.instance.isLiked(trackId);
    final playing = widget.controller.pagePlaying == true;
    final muted =
        widget.controller.audioState == VShotsAudioState.playingMutedContent;
    final loading = widget.controller.isLoading ||
        widget.controller.playbackState == VShotsPlaybackState.buffering ||
        widget.controller.playbackState == VShotsPlaybackState.loading;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xF3171A2A), Color(0xFF080B13)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          18,
          10,
          18,
          MediaQuery.of(context).padding.bottom + 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.fast,
                    child: Column(
                      key: ValueKey<String>(trackId),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (track['isOfficial'] == true) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: AppColors.accent,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _RoundIconButton(
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isLiked ? AppColors.hotPink : AppColors.textMain,
                  tooltip: isLiked ? 'Unlike' : 'Like',
                  onPressed: () {
                    final wasLiked = isLiked;
                    unawaited(
                      LocalLibrary.instance.toggleLiked(track).then((_) {
                        if (wasLiked) {
                          playbackSignalTracker.onUnliked(track);
                        } else {
                          playbackSignalTracker.onLiked(track);
                        }
                        if (mounted) setState(() {});
                      }),
                    );
                  },
                ),
                const SizedBox(width: 4),
                _RoundIconButton(
                  icon: Icons.more_horiz_rounded,
                  color: AppColors.textSecondary,
                  tooltip: 'More options',
                  onPressed: () => _openPlayerActions(track),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.controller.durationMs > 0)
              _buildProgressControl()
            else
              Row(
                children: [
                  Icon(
                    muted ? Icons.volume_off_rounded : Icons.graphic_eq_rounded,
                    size: 15,
                    color: muted ? AppColors.warning : AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _audioLabel(),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundIconButton(
                  icon: manager.isShuffleOn
                      ? Icons.shuffle_on_rounded
                      : Icons.shuffle_rounded,
                  color: manager.isShuffleOn
                      ? AppColors.accent
                      : AppColors.textMuted,
                  tooltip: 'Shuffle',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(manager.toggleShuffle);
                  },
                ),
                _RoundIconButton(
                  icon: Icons.skip_previous_rounded,
                  color: manager.queue.length > 1
                      ? AppColors.textMain
                      : AppColors.textSubtle,
                  tooltip: 'Previous',
                  onPressed: manager.queue.length > 1 ? manager.previous : null,
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: loading
                        ? null
                        : () async {
                            await HapticFeedback.mediumImpact();
                            await _togglePagePlayback();
                          },
                    borderRadius: BorderRadius.circular(40),
                    child: Ink(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: loading
                            ? const LinearGradient(
                                colors: [AppColors.surface2, AppColors.surface],
                              )
                            : AppColors.primaryGradient,
                        boxShadow: loading
                            ? null
                            : [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 22,
                                  spreadRadius: 2,
                                ),
                              ],
                      ),
                      child: Center(
                        child: loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : AnimatedSwitcher(
                                duration: AppMotion.micro,
                                child: Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  key: ValueKey<bool>(playing),
                                  size: 37,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                _RoundIconButton(
                  icon: Icons.skip_next_rounded,
                  color: manager.queue.length > 1
                      ? AppColors.textMain
                      : AppColors.textSubtle,
                  tooltip: 'Next',
                  onPressed: manager.queue.length > 1 ? manager.next : null,
                ),
                _RoundIconButton(
                  icon: switch (manager.repeatMode) {
                    PlaybackRepeat.off => Icons.repeat_rounded,
                    PlaybackRepeat.all => Icons.repeat_rounded,
                    PlaybackRepeat.one => Icons.repeat_one_rounded,
                  },
                  color: manager.repeatMode == PlaybackRepeat.off
                      ? AppColors.textMuted
                      : AppColors.accent,
                  tooltip: 'Repeat',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(manager.cycleRepeat);
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ActionPill(
                    icon: muted
                        ? Icons.volume_up_rounded
                        : Icons.graphic_eq_rounded,
                    label: muted ? 'Enable sound' : _audioLabel(),
                    highlighted: muted,
                    onPressed: muted ? _enableAudio : null,
                  ),
                  _ActionPill(
                    icon: Icons.queue_music_rounded,
                    label: 'Queue',
                    onPressed: _openQueueSheet,
                  ),
                  _ActionPill(
                    icon: Icons.playlist_add_rounded,
                    label: 'Playlist',
                    onPressed: () => showAddToPlaylistSheet(context, track),
                  ),
                  _ActionPill(
                    icon: Icons.lyrics_outlined,
                    label: 'Lyrics',
                    onPressed: _openPlayerLyrics,
                  ),
                  _ActionPill(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text: 'Listen to "$title" by $artist on V Shots: '
                            'https://www.youtube.com/watch?v=$trackId',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.controller.adActive) ...[
              const SizedBox(height: 10),
              const _StatusPill(
                icon: Icons.campaign_rounded,
                label: 'Official ad muted',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressControl() {
    final duration = widget.controller.durationMs;
    final current = _isSeeking
        ? (_seekPreviewMs ?? widget.controller.positionMs)
        : widget.controller.positionMs.toDouble();
    final value = duration <= 0 ? 0.0 : (current / duration).clamp(0.0, 1.0);
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
            thumbColor: Colors.white,
            overlayColor: AppColors.accent.withValues(alpha: 0.16),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 1,
            onChangeStart: (_) {
              setState(() {
                _isSeeking = true;
                _seekPreviewMs = widget.controller.positionMs.toDouble();
              });
            },
            onChanged: (next) {
              setState(() => _seekPreviewMs = next * duration);
            },
            onChangeEnd: (next) async {
              final target = Duration(milliseconds: (next * duration).round());
              await HapticFeedback.selectionClick();
              await _session.seekTo(target);
              if (mounted) {
                setState(() {
                  _isSeeking = false;
                  _seekPreviewMs = null;
                });
              }
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatTime(current.round()),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            Text(
              _formatTime(duration),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  void _openPlayerActions(Map<String, dynamic> track) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PremiumActionSheet(
        onPlaylist: () {
          Navigator.of(sheetContext).pop();
          showAddToPlaylistSheet(context, track);
        },
        onLyrics: () {
          Navigator.of(sheetContext).pop();
          _openPlayerLyrics();
        },
        onShare: () {
          Navigator.of(sheetContext).pop();
          SharePlus.instance.share(
            ShareParams(
              text: 'Listen to "${track['title'] ?? ''}" on V Shots: '
                  'https://www.youtube.com/watch?v=${track['id'] ?? ''}',
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: const Color(0xFF0A0D16),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.signal_wifi_connected_no_internet_4_rounded,
                size: 44,
                color: AppColors.textSubtle,
              ),
              const SizedBox(height: 12),
              Text(
                widget.controller.error ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadForCurrent,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: color,
      disabledColor: AppColors.textSubtle,
      tooltip: tooltip,
      iconSize: 27,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(99),
          child: AnimatedContainer(
            duration: AppMotion.micro,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: highlighted
                  ? AppColors.accent.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: enabled ? 0.07 : 0.04),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: highlighted
                    ? AppColors.accent.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: highlighted
                      ? AppColors.accentLight
                      : enabled
                          ? AppColors.textSecondary
                          : AppColors.textSubtle,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: highlighted
                        ? AppColors.textMain
                        : enabled
                            ? AppColors.textSecondary
                            : AppColors.textSubtle,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.accent),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumLoadingOverlay extends StatelessWidget {
  const _PremiumLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.background.withValues(alpha: 0.34),
                AppColors.background.withValues(alpha: 0.76),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const Center(
            child: _StatusPill(
              icon: Icons.auto_awesome_rounded,
              label: 'Preparing your track',
            ),
          ),
        ),
      ),
    );
  }
}

class _SoundPrompt extends StatelessWidget {
  const _SoundPrompt({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: const Color(0xE8171A2A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.volume_off_rounded,
                color: AppColors.warning, size: 28),
            const SizedBox(height: 8),
            const Text(
              'Sound is off',
              style: TextStyle(
                color: AppColors.textMain,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap once to enable audio without pausing the video.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : onPressed,
              icon: busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.volume_up_rounded, size: 18),
              label: Text(busy ? 'Enabling…' : 'Enable sound'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumQueueSheet extends StatelessWidget {
  const _PremiumQueueSheet({
    required this.queue,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> queue;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.78,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0C101B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Up next',
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${queue.length} tracks',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: queue.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final track = queue[index];
                    final selected = index == currentIndex;
                    return Material(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.035),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: () => onSelect(index),
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AppImage(
                                  track['artwork'] as String?,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (track['title'] as String?) ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: selected
                                            ? AppColors.accentLight
                                            : AppColors.textMain,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      (track['artist'] as String?) ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                const AnimatedEqualizer(
                                  size: 18,
                                  color: AppColors.accent,
                                )
                              else
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  color: AppColors.textSubtle,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumActionSheet extends StatelessWidget {
  const _PremiumActionSheet({
    required this.onPlaylist,
    required this.onLyrics,
    required this.onShare,
  });

  final VoidCallback onPlaylist;
  final VoidCallback onLyrics;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF151A29),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded,
                  color: AppColors.accent),
              title: const Text('Add to playlist',
                  style: TextStyle(color: AppColors.textMain)),
              onTap: onPlaylist,
            ),
            ListTile(
              leading:
                  const Icon(Icons.lyrics_outlined, color: AppColors.accent),
              title: const Text('View lyrics',
                  style: TextStyle(color: AppColors.textMain)),
              onTap: onLyrics,
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: AppColors.accent),
              title: const Text('Share track',
                  style: TextStyle(color: AppColors.textMain)),
              onTap: onShare,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small source badge for the mini-player thumbnail.
/// Small "Ad" pill shown while the official YouTube player runs an
/// in-stream ad (mute/skip/resume handled natively — this is UI only).
class _AdBadge extends StatelessWidget {
  const _AdBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.hotPink.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'AD',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final isJio = source.toLowerCase().contains('jiosaavn');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: isJio ? const Color(0xE61DB954) : const Color(0xE6FF0000),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, size: 8, color: Colors.white),
          Text(
            isJio ? 'JioSaavn' : 'YouTube',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 7,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

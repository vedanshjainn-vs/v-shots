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

import 'package:share_plus/share_plus.dart';

import '../../core/playback/vshots_playback_manager.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart'
    show LyricsScreen, playbackSignalTracker, showAddToPlaylistSheet;
import '../../shared/widgets/app_image.dart';
import 'discovery_browser_controller.dart';
import 'vshots_browser_session.dart';

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
    // The single browser session: owns the native WebView + lifecycle; the
    // sheet is only the UI/interaction layer. Minimizing never destroys the
    // session.
    _session = VShotsBrowserSession(
      onPageStarted: () => widget.controller.setLoading(true),
      onPageFinished: () => widget.controller.setLoading(false),
      onError: (message) {
        widget.controller.setLoading(false);
        widget.controller.setError(message);
      },
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
    widget.controller.extentCommand.removeListener(_onExtentCommand);
    widget.controller.removeListener(_onControllerChanged);
    _extent.dispose();
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

  void _onDragStart(DragStartDetails details) {
    _downPixels = 0;
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
    // Dismiss: a deliberate downward fling OR a firm downward pull while
    // (near-)collapsed closes the browser. A tiny tap or a few pixels of
    // noise never reaches this.
    final fastDownFling = velocity > 450;
    final firmDownPull = _downPixels > 80;
    if ((fastDownFling || firmDownPull) && _extent.value < 0.25) {
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

  Future<void> _loadForCurrent() async {
    final url = widget.controller.url;
    if (url == null) return;
    _lastLoadedUrl = url;
    widget.controller.setLoading(true);
    widget.controller.setError(null);
    await _session.load(url);
  }

  Future<void> _togglePagePlayback() async {
    final result = await _session.togglePagePlayback();
    if (result == null) {
      await _loadForCurrent();
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
      if (mounted) widget.controller.close();
    });
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
    return GestureDetector(
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Container(
        color: const Color(0xFF0A0D16),
        padding: EdgeInsets.only(
          left: 4,
          right: 4,
          top: MediaQuery.of(context).padding.top + 6,
          bottom: 4,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
                size: 28,
              ),
              tooltip: 'Minimize',
              onPressed: () => _animateTo(0.0),
            ),
            const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textSubtle,
              size: 14,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _displayUrl(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: 'Close',
              onPressed: _close,
            ),
          ],
        ),
      ),
    );
  }

  String _displayUrl() {
    final id = widget.controller.videoId ?? '';
    return 'm.youtube.com/watch?v=$id';
  }

  // ── Collapsed mini player ────────────────────────────────────────────────

  Widget _buildMiniPlayer() {
    final title = widget.controller.title ?? 'Playing video';
    final artist = widget.controller.artist ?? '';
    final artwork = widget.controller.artwork;

    return GestureDetector(
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      onTap: () => _animateTo(1.0),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: const Color(0xF20E111C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AppImage(
                    artwork,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorIconColor: AppColors.accent,
                  ),
                ),
                if (widget.controller.isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
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
                const Positioned(left: 4, bottom: 4, child: _YoutubeBadge()),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.pause_rounded,
                color: AppColors.accent,
                size: 28,
              ),
              tooltip: 'Pause / Resume',
              onPressed: _togglePagePlayback,
            ),
            IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: AppColors.textMuted,
                size: 24,
              ),
              tooltip: 'Expand',
              onPressed: () => _animateTo(1.0),
            ),
          ],
        ),
      ),
    );
  }

  // ── Expanded body (native browser / loading / error) ────────────────────

  Widget _buildBrowserBody() {
    if (widget.controller.error != null) return _buildError();
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _session.buildWidget(),
              if (widget.controller.isLoading)
                IgnorePointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                      ),
                    ),
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

  /// The app-level full-player controls over the WebView engine. The real
  /// YouTube page provides its own seek bar; V Shots adds queue control
  /// (prev/next/shuffle/repeat), like, playlist, lyrics and share.
  Widget _buildExpandedControls() {
    final mgr = VShotsPlaybackManager.instance;
    final track = widget.controller.track ?? const {};
    final title = (track['title'] as String?) ?? '';
    final artist = (track['artist'] as String?) ?? '';
    final trackId = (track['id'] as String?) ?? '';
    final isLiked =
        trackId.isNotEmpty && LocalLibrary.instance.isLiked(trackId);
    final playing = widget.controller.pagePlaying != false;

    return Container(
      color: const Color(0xFF0A0D16),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 6,
        bottom: MediaQuery.of(context).padding.bottom + 6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Metadata
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (track['isOfficial'] == true) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 13,
                            color: AppColors.accent,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                ),
                tooltip: 'Close',
                onPressed: _close,
              ),
            ],
          ),
          // Primary controls: shuffle / prev / play-pause / next / repeat.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  mgr.isShuffleOn
                      ? Icons.shuffle_on_rounded
                      : Icons.shuffle_rounded,
                  color: mgr.isShuffleOn ? AppColors.accent : Colors.white60,
                ),
                tooltip: 'Shuffle',
                onPressed: () => setState(mgr.toggleShuffle),
              ),
              IconButton(
                icon: const Icon(
                  Icons.skip_previous_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                tooltip: 'Previous',
                onPressed: mgr.previous,
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(
                  playing
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: AppColors.accent,
                  size: 52,
                ),
                tooltip: playing ? 'Pause' : 'Play',
                onPressed: () async {
                  await _togglePagePlayback();
                  setState(() {});
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                tooltip: 'Next',
                onPressed: mgr.next,
              ),
              IconButton(
                icon: Icon(
                  switch (mgr.repeatMode) {
                    PlaybackRepeat.off => Icons.repeat_rounded,
                    PlaybackRepeat.all => Icons.repeat_rounded,
                    PlaybackRepeat.one => Icons.repeat_one_rounded,
                  },
                  color: mgr.repeatMode == PlaybackRepeat.off
                      ? Colors.white60
                      : AppColors.accent,
                ),
                tooltip: 'Repeat',
                onPressed: () => setState(mgr.cycleRepeat),
              ),
            ],
          ),
          // Secondary actions.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isLiked ? AppColors.hotPink : Colors.white70,
                ),
                tooltip: 'Like',
                onPressed: () {
                  final wasLiked = isLiked;
                  LocalLibrary.instance.toggleLiked(track).then((_) {
                    if (wasLiked) {
                      playbackSignalTracker.onUnliked(track);
                    } else {
                      playbackSignalTracker.onLiked(track);
                    }
                    if (mounted) setState(() {});
                  });
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.playlist_add_rounded,
                  color: Colors.white70,
                ),
                tooltip: 'Add to playlist',
                onPressed: () => showAddToPlaylistSheet(context, track),
              ),
              IconButton(
                icon: const Icon(
                  Icons.lyrics_outlined,
                  color: Colors.white70,
                ),
                tooltip: 'Lyrics',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => LyricsScreen(track: track),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.share_rounded,
                  color: Colors.white70,
                ),
                tooltip: 'Share',
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: 'Listen to "$title" by $artist on V Shots: '
                        'https://www.youtube.com/watch?v=$trackId',
                  ),
                ),
              ),
            ],
          ),
          // Queue
          if (mgr.queue.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  const Text(
                    'Up Next',
                    style: TextStyle(
                      color: AppColors.textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${mgr.queue.length} tracks',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 132,
              child: ListView.builder(
                itemCount: mgr.queue.length,
                itemBuilder: (context, i) {
                  final t = mgr.queue[i];
                  final isCurrent = i == mgr.currentIndex;
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    tileColor: isCurrent
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AppImage(
                        t['artwork'] as String?,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      (t['title'] as String?) ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            isCurrent ? AppColors.accent : AppColors.textMain,
                        fontSize: 13,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      (t['artist'] as String?) ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    onTap: () => mgr.jumpTo(i),
                  );
                },
              ),
            ),
          ],
        ],
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

/// Small red "YouTube" badge for the mini-player thumbnail.
class _YoutubeBadge extends StatelessWidget {
  const _YoutubeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xE6FF0000),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, size: 8, color: Colors.white),
          Text(
            'YouTube',
            style: TextStyle(
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

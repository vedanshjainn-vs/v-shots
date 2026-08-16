// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discovery in-app YouTube browser (mini player + expandable sheet)
// ═════════════════════════════════════════════════════════════════════════════
//
// Discovery-scoped, draggable bottom sheet that opens the OFFICIAL YouTube
// watch page (https://www.youtube.com/watch?v=<id>) inside the app — the real
// YouTube web content, never a fake player. States:
//   collapsed  → a compact glass mini player above the bottom navigation
//   expanded   → browser bar (minimize / lock+URL / close) over the live page
//
// Playback continuity: the WebView is created ONCE per session and stays
// mounted at every sheet size, so minimizing keeps the video playing. Closing
// removes the sheet (and therefore the WebView) entirely.
//
// BACKGROUND-PLAYBACK LIMITATION (documented honestly): WebView-based YouTube
// playback is not guaranteed while the OS backgrounds the app or locks the
// screen (YouTube's web player pauses in backgrounded webviews; Android may
// also stop the page). We do NOT fake background audio or add brittle
// workarounds. In-app continuity (collapse/expand/tab-switch via IndexedStack)
// works because the WebView stays alive in the tree. The existing
// audio_service global player remains the app's true background-playback path
// for the licensed/audio pipeline.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import 'discovery_browser_controller.dart';

class DiscoveryBrowserSheet extends StatefulWidget {
  const DiscoveryBrowserSheet({super.key, required this.controller});

  final DiscoveryBrowserController controller;

  @override
  State<DiscoveryBrowserSheet> createState() => _DiscoveryBrowserSheetState();
}

class _DiscoveryBrowserSheetState extends State<DiscoveryBrowserSheet> {
  final DraggableScrollableController _sheet = DraggableScrollableController();
  WebViewController? _webViewController;
  String? _lastLoadedUrl;
  bool _collapsed = true;

  static const double _minExtent = 0.10;
  static const double _midExtent = 0.45;
  static const double _maxExtent = 0.92;
  static const List<double> _snaps = [_minExtent, _midExtent, _maxExtent];

  @override
  void initState() {
    super.initState();
    // Start collapsed (0.10) before the sheet attaches.
    _sheet.jumpTo(_minExtent);
    _sheet.addListener(_onExtentChanged);
    widget.controller.addListener(_onControllerChanged);
    _loadForCurrent();
  }

  @override
  void dispose() {
    _sheet.removeListener(_onExtentChanged);
    widget.controller.removeListener(_onControllerChanged);
    _sheet.dispose();
    // The platform WebView is disposed when WebViewWidget is removed from the
    // tree (on close); dropping our reference here releases it.
    _webViewController = null;
    super.dispose();
  }

  void _onExtentChanged() {
    final collapsed = _sheet.size < 0.3;
    if (collapsed != _collapsed) {
      setState(() => _collapsed = collapsed);
      widget.controller.setExpanded(!collapsed);
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (!widget.controller.isOpen) return;
    final url = widget.controller.url;
    if (url != null && url != _lastLoadedUrl) {
      // Video switched: collapse back to the mini player and reload.
      if (_sheet.size > _minExtent) _sheet.jumpTo(_minExtent);
      _loadForCurrent();
    }
    setState(() {});
  }

  // ── WebView lifecycle ────────────────────────────────────────────────────

  Future<WebViewController> _createWebViewController() async {
    final webViewController = WebViewController();
    await webViewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await webViewController.setBackgroundColor(Colors.black);
    await webViewController.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) => widget.controller.setLoading(true),
        onPageFinished: (_) => widget.controller.setLoading(false),
        onWebResourceError: (error) {
          widget.controller.setLoading(false);
          widget.controller.setError('Playback failed — please retry');
        },
        onNavigationRequest: (request) => _isAllowedNavigation(request.url)
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ),
    );
    // Android: allow the official YouTube page's media to start without an
    // extra in-page tap (the user already tapped Play in the app).
    try {
      final android = webViewController.platform as AndroidWebViewController;
      await android.setMediaPlaybackRequiresUserGesture(false);
    } catch (_) {
      // Non-Android or platform not ready — page still loads; the user can
      // tap YouTube's own play button.
    }
    return webViewController;
  }

  /// Only allow YouTube/Google infrastructure hosts; anything else is blocked
  /// in place so the browser never wanders off to arbitrary external sites.
  bool _isAllowedNavigation(String url) {
    String host;
    try {
      host = Uri.parse(url).host.toLowerCase();
    } catch (_) {
      return false;
    }
    const allowed = [
      'youtube.com',
      'youtu.be',
      'googlevideo.com',
      'ytimg.com',
      'google.com',
      'gstatic.com',
      'ggpht.com',
    ];
    return allowed.any((h) => host == h || host.endsWith('.$h'));
  }

  Future<void> _loadForCurrent() async {
    final url = widget.controller.url;
    if (url == null) return;
    _lastLoadedUrl = url;
    widget.controller.setLoading(true);
    widget.controller.setError(null);
    final webViewController =
        _webViewController ??= await _createWebViewController();
    try {
      await webViewController.loadRequest(Uri.parse(url));
    } catch (e) {
      widget.controller.setLoading(false);
      widget.controller.setError('Could not open this video');
    }
  }

  Future<void> _togglePagePlayback() async {
    final wc = _webViewController;
    if (wc == null) {
      await _loadForCurrent();
      return;
    }
    try {
      final result = await wc.runJavaScriptReturningResult(
        "(function(){var v=document.querySelector('video');"
        "if(!v){return 'none';}"
        "if(v.paused){v.play();return 'playing';}"
        "v.pause();return 'paused';})()",
      );
      final state = result.toString();
      if (state.contains('playing')) {
        widget.controller.setPagePlaying(true);
      } else if (state.contains('paused')) {
        widget.controller.setPagePlaying(false);
      }
    } catch (_) {
      // Non-fatal: page structure unknown / webview not ready.
    }
  }

  void _close() {
    if (!_collapsed) {
      _sheet
          .animateTo(
        _minExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeIn,
      )
          .then((_) {
        if (mounted) widget.controller.close();
      });
    } else {
      widget.controller.close();
    }
  }

  // ── Manual drag (finger-connected, snaps) ────────────────────────────────

  void _onDragUpdate(DragUpdateDetails details, double sheetHeight) {
    if (sheetHeight <= 0) return;
    final deltaExtent = -details.delta.dy / sheetHeight;
    final next = (_sheet.size + deltaExtent).clamp(_minExtent, _maxExtent);
    _sheet.jumpTo(next);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final target = _snapTarget(_sheet.size, velocity);
    _sheet.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  double _snapTarget(double current, double velocity) {
    if (velocity < -600) return _maxExtent; // fling up
    if (velocity > 600) return _minExtent; // fling down
    var best = _snaps.first;
    var bestDistance = (current - best).abs();
    for (final snap in _snaps.skip(1)) {
      final distance = (current - snap).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = snap;
      }
    }
    return best;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sheetHeight = constraints.maxHeight;
        return DraggableScrollableSheet(
          controller: _sheet,
          minChildSize: _minExtent,
          maxChildSize: _maxExtent,
          snap: true,
          snapSizes: _snaps,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color:
                    _collapsed ? Colors.transparent : const Color(0xF20A0D16),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(_collapsed ? 20 : 0),
                ),
                boxShadow: _collapsed
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, -4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  if (!_collapsed) _buildBrowserBar(),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // The live YouTube page — mounted once per session so
                        // audio keeps playing while minimized.
                        if (_webViewController != null)
                          WebViewWidget(controller: _webViewController!),
                        if (_collapsed)
                          _buildMiniPlayer(sheetHeight)
                        else ...[
                          if (widget.controller.isLoading) _buildLoading(),
                          if (widget.controller.error != null) _buildError(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Expanded browser bar ─────────────────────────────────────────────────

  Widget _buildBrowserBar() {
    return GestureDetector(
      onVerticalDragUpdate: (d) => _onDragUpdate(d, _sheetAreaHeight()),
      onVerticalDragEnd: _onDragEnd,
      child: Container(
        color: const Color(0xFF0A0D16),
        padding: EdgeInsets.only(
          left: 4,
          right: 4,
          top: MediaQuery.of(context).padding.top + 4,
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
              onPressed: () => _sheet.animateTo(
                _minExtent,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
              ),
            ),
            const Icon(Icons.lock_outline_rounded,
                color: AppColors.textSubtle, size: 14),
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

  Widget _buildMiniPlayer(double sheetHeight) {
    final title = widget.controller.title ?? 'Playing video';
    final artist = widget.controller.artist ?? '';
    final artwork = widget.controller.artwork;

    return GestureDetector(
      onVerticalDragUpdate: (d) => _onDragUpdate(d, sheetHeight),
      onVerticalDragEnd: _onDragEnd,
      onTap: () => _sheet.animateTo(
        _maxExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
      child: Container(
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
                const Positioned(
                  left: 4,
                  bottom: 4,
                  child: _YoutubeBadge(),
                ),
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
              onPressed: () => _sheet.animateTo(
                _maxExtent,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    final artwork = widget.controller.artwork;
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (artwork != null && artwork.isNotEmpty)
            AppImage(artwork, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.6)),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.accent),
                SizedBox(height: 14),
                Text(
                  'Loading video…',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
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

  double _sheetAreaHeight() {
    final size = MediaQuery.of(context).size;
    // The sheet occupies the Discovery body area (above bottom nav); using
    // screen height is a close-enough scale for the finger-follow drag.
    return size.height;
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

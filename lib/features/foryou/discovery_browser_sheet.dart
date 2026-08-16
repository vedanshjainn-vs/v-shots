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
// snap). The WebView is created ONCE per session and stays mounted (clipped,
// not removed) while collapsed so playback continues; closing removes it.
//
// BACKGROUND-PLAYBACK LIMITATION (documented honestly): WebView-based YouTube
// playback is not guaranteed while the OS backgrounds the app or locks the
// screen (YouTube pauses backgrounded webviews). We do NOT fake background
// audio. In-app continuity (collapse/expand, tab-switch) works because the
// WebView stays alive in the tree. The audio_service global player remains the
// app's true background-playback path.
// ═════════════════════════════════════════════════════════════════════════════

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

class _DiscoveryBrowserSheetState extends State<DiscoveryBrowserSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _extent;
  WebViewController? _webViewController;
  String? _lastLoadedUrl;

  static const double _miniHeight = 84;
  static const double _maxFraction = 0.92;

  @override
  void initState() {
    super.initState();
    _extent = AnimationController(vsync: this, value: 0.0);
    _extent.addListener(_onExtentTick);
    widget.controller.addListener(_onControllerChanged);
    _loadForCurrent();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _extent.dispose();
    _webViewController = null;
    super.dispose();
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

  void _onDragUpdate(DragUpdateDetails details) {
    final maxH = MediaQuery.of(context).size.height * _maxFraction;
    final travel = maxH - _miniHeight;
    if (travel <= 0) return;
    final delta = -details.delta.dy / travel;
    _extent.value = (_extent.value + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    double target;
    if (velocity < -600) {
      target = 1.0; // fling up → expand
    } else if (velocity > 600) {
      target = 0.0; // fling down → collapse
    } else if (_extent.value > 0.45) {
      target = 1.0;
    } else {
      target = 0.0;
    }
    _animateTo(target);
  }

  void _animateTo(double target) {
    _extent.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
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

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * _maxFraction;
    return AnimatedBuilder(
      animation: _extent,
      builder: (context, _) {
        final e = _extent.value;
        final currentH = _miniHeight + e * (maxH - _miniHeight);
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: currentH,
            width: double.infinity,
            child: ClipRect(
              child: Stack(
                children: [
                  // Expanded browser content — kept mounted at full size and
                  // CLIPPED while collapsed so the WebView keeps playing.
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: e < 0.5,
                      child: SizedBox(
                        height: maxH,
                        child: Column(
                          children: [
                            _buildBrowserBar(),
                            Expanded(child: _buildBrowserBody()),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Collapsed mini player — fades out as the sheet expands.
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
            ),
          ),
        );
      },
    );
  }

  // ── Expanded browser bar ─────────────────────────────────────────────────

  Widget _buildBrowserBar() {
    return GestureDetector(
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

  // ── Expanded body (WebView / loading / error) ────────────────────────────

  Widget _buildBrowserBody() {
    if (widget.controller.error != null) return _buildError();
    final wc = _webViewController;
    if (wc == null) return _buildLoading();
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: wc),
        // A brief loading veil on top while the page is still starting; the
        // YouTube page then takes over its own rendering.
        if (widget.controller.isLoading)
          IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          ),
      ],
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

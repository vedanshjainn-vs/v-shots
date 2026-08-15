import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/theme/app_colors.dart';

/// One persistent YouTube WebView used everywhere in V Shots.
/// The WebView itself never gets recreated when tabs change; only its size
/// changes between the mini and expanded states.
class BrowserPlayerOverlay extends StatefulWidget {
  const BrowserPlayerOverlay({
    required this.track,
    required this.expanded,
    required this.onToggleExpand,
    required this.onTrackEnded,
    super.key,
  });

  final Map<String, dynamic> track;
  final bool expanded;
  final ValueChanged<bool> onToggleExpand;
  final VoidCallback onTrackEnded;

  @override
  State<BrowserPlayerOverlay> createState() => _BrowserPlayerOverlayState();
}

class _BrowserPlayerOverlayState extends State<BrowserPlayerOverlay> {
  InAppWebViewController? _controller;
  String? _loadedVideoId;
  bool _loading = true;
  bool _endSent = false;

  InAppWebViewSettings get _settings => InAppWebViewSettings(
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
        mediaPlaybackRequiresUserGesture: false,
        allowBackgroundAudioPlaying: true,
        allowsInlineMediaPlayback: true,
        allowsPictureInPictureMediaPlayback: true,
        thirdPartyCookiesEnabled: true,
        domStorageEnabled: true,
        supportZoom: false,
        transparentBackground: true,
        isElementFullscreenEnabled: true,
        iframeAllow: 'autoplay; encrypted-media; picture-in-picture; fullscreen',
        iframeAllowFullscreen: true,
      );

  String _watchUrl(String id) =>
      'https://m.youtube.com/watch?v=$id&autoplay=1&playsinline=1';

  @override
  void initState() {
    super.initState();
    _loadedVideoId = widget.track['id'] as String?;
  }

  @override
  void didUpdateWidget(covariant BrowserPlayerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newId = widget.track['id'] as String?;
    if (newId != null && newId.isNotEmpty && newId != _loadedVideoId) {
      _loadedVideoId = newId;
      _endSent = false;
      _loading = true;
      final controller = _controller;
      if (controller != null) {
        unawaited(controller.loadUrl(urlRequest: URLRequest(url: WebUri(_watchUrl(newId)))));
      }
    }
  }

  Future<void> _installEndWatcher() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.evaluateJavascript(source: '''
      (() => {
        if (window.__vshotsEndWatcher) clearInterval(window.__vshotsEndWatcher);
        window.__vshotsEndWatcher = setInterval(() => {
          const video = document.querySelector('video');
          if (video && video.ended) {
            window.flutter_inappwebview.callHandler('vshotsVideoEnded');
          }
        }, 750);
      })();
    ''');
  }

  Future<void> _playCurrent() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.evaluateJavascript(source: '''
      (() => {
        const video = document.querySelector('video');
        if (video) { video.muted = false; video.play().catch(() => {}); }
      })();
    ''');
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.track['id'] as String? ?? '';
    if (id.isEmpty) return const SizedBox.shrink();

    final webView = ClipRRect(
      borderRadius: BorderRadius.circular(widget.expanded ? 16 : 14),
      child: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_watchUrl(id))),
            initialSettings: _settings,
            onWebViewCreated: (controller) {
              _controller = controller;
              controller.addJavaScriptHandler(
                handlerName: 'vshotsVideoEnded',
                callback: (_) {
                  if (_endSent) return null;
                  _endSent = true;
                  widget.onTrackEnded();
                  return null;
                },
              );
            },
            onLoadStart: (_, __) {
              if (mounted) setState(() => _loading = true);
            },
            onLoadStop: (controller, __) async {
              if (!mounted) return;
              setState(() => _loading = false);
              await _installEndWatcher();
              // The WebView is configured for autoplay. This second attempt
              // catches pages where the HTML video appears after the document.
              await Future<void>.delayed(const Duration(milliseconds: 900));
              await _playCurrent();
            },
            onConsoleMessage: (_, message) {
              if (message.message.contains('vshotsVideoEnded')) {
                if (!_endSent) {
                  _endSent = true;
                  widget.onTrackEnded();
                }
              }
            },
          ),
          if (_loading && widget.expanded)
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (!widget.expanded) {
      return Positioned(
        left: 10,
        right: 10,
        bottom: 68,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () => widget.onToggleExpand(true),
            child: Container(
              height: 132,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  SizedBox(width: 214, height: 120, child: webView),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.track['title'] as String? ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.track['artist'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: _playCurrent,
                              icon: const Icon(Icons.play_arrow_rounded, color: AppColors.accent),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => widget.onToggleExpand(true),
                              icon: const Icon(Icons.open_in_full_rounded, size: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Material(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => widget.onToggleExpand(false),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                    ),
                    const Expanded(
                      child: Column(
                        children: [
                          Text('PLAYING FROM', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          Text('Official YouTube Web Player', style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _controller?.goBack, icon: const Icon(Icons.arrow_back_rounded)),
                    IconButton(onPressed: _controller?.goForward, icon: const Icon(Icons.arrow_forward_rounded)),
                    IconButton(onPressed: _controller?.reload, icon: const Icon(Icons.refresh_rounded)),
                  ],
                ),
              ),
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: webView)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.track['title'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      widget.track['artist'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
}

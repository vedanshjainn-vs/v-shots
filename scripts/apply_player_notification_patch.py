from pathlib import Path

ROOT = Path('.')


def patch(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'player notification anchor not found: {path}')
    p.write_text(text.replace(old, new, 1))


def patch_main_audio_service() -> None:
    path = 'lib/main.dart'
    p = ROOT / path
    text = p.read_text()
    text = text.replace(
        '      androidStopForegroundOnPause: true,\n',
        '      androidStopForegroundOnPause: false,\n',
        1,
    )
    text = text.replace(
        '      androidShowNotificationBadge: true,\n',
        '      androidShowNotificationBadge: false,\n',
        1,
    )
    p.write_text(text)
    patch(
        path,
        """      androidNotificationClickStartsActivity: true,
    ),""",
        """      androidNotificationClickStartsActivity: true,
      androidResumeOnClick: true,
      notificationColor: const Color(0xFF111522),
      preloadArtwork: true,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),""",
    )


def patch_native_browser() -> None:
    path = 'android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlatformView.kt'
    p = ROOT / path
    patch(path, '    init {\n        setBackgroundColor(Color.BLACK)\n', '    init {\n        VShotsBrowserPlaybackService.eventChannel = events\n        setBackgroundColor(Color.BLACK)\n')
    patch(path, '''    fun setMediaPlaying(value: Boolean) {
        if (mediaPlaying == value) return
        mediaPlaying = value
        if (value) {
            startPlaybackForegroundService()
        } else {
            stopPlaybackForegroundService()
        }
        events.invokeMethod("playbackState", value)
    }
''', '''    fun setMediaPlaying(value: Boolean) {
        if (mediaPlaying == value) {
            updatePlaybackNotification(value)
            return
        }
        mediaPlaying = value
        startPlaybackForegroundService(playing = value)
        events.invokeMethod("playbackState", value)
    }

    fun updateNotification(title: String, artist: String, artwork: String, playing: Boolean) {
        startPlaybackForegroundService(title = title, artist = artist, artwork = artwork, playing = playing)
    }
''')
    patch(path, '''    private fun startPlaybackForegroundService() {
        val intent = Intent(appContext, VShotsBrowserPlaybackService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                appContext.startForegroundService(intent)
            } else {
                appContext.startService(intent)
            }
        } catch (_: Exception) {
            // FGS startup is a hardening layer and must never crash Discovery.
        }
    }
''', '''    private fun startPlaybackForegroundService(
        title: String? = null,
        artist: String? = null,
        artwork: String? = null,
        playing: Boolean = mediaPlaying,
    ) {
        val intent = Intent(appContext, VShotsBrowserPlaybackService::class.java).apply {
            action = VShotsBrowserPlaybackService.ACTION_UPDATE
            putExtra("title", title ?: "V Shots")
            putExtra("artist", artist ?: "Music playback")
            putExtra("artwork", artwork ?: "")
            putExtra("playing", playing)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                appContext.startForegroundService(intent)
            } else {
                appContext.startService(intent)
            }
        } catch (_: Exception) {
            // FGS startup is a hardening layer and must never crash Discovery.
        }
    }

    private fun updatePlaybackNotification(playing: Boolean) {
        startPlaybackForegroundService(playing = playing)
    }
''')
    patch(path, '''    fun disposeMedia() {
        stopPlaybackPolling()
        setMediaPlaying(false)
        stopLoading()
        loadUrl("about:blank")
    }
''', '''    fun disposeMedia() {
        stopPlaybackPolling()
        stopPlaybackForegroundService()
        if (VShotsBrowserPlaybackService.eventChannel === events) {
            VShotsBrowserPlaybackService.eventChannel = null
        }
        mediaPlaying = false
        stopLoading()
        loadUrl("about:blank")
    }
''')
    patch(path, '''                "setAdAssist" -> {
                    webView.setAdAssist((call.arguments as? Boolean) ?: true)
                    result.success(null)
                }
''', '''                "setAdAssist" -> {
                    webView.setAdAssist((call.arguments as? Boolean) ?: true)
                    result.success(null)
                }
                "updateNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    val title = args?.get("title")?.toString() ?: "V Shots"
                    val artist = args?.get("artist")?.toString() ?: "Music playback"
                    val artwork = args?.get("artwork")?.toString() ?: ""
                    val playing = args?.get("playing") as? Boolean ?: true
                    webView.updateNotification(title, artist, artwork, playing)
                    result.success(null)
                }
''')


def patch_session() -> None:
    path = 'lib/features/foryou/vshots_browser_session.dart'
    p = ROOT / path
    text = p.read_text()
    if 'onNotificationAction' not in text:
        text = text.replace('    this.onAdState,\n', '    this.onAdState,\n    this.onNotificationAction,\n', 1)
        text = text.replace('  final void Function(bool adActive)? onAdState;\n', '''  final void Function(bool adActive)? onAdState;

  final Future<void> Function(String action)? onNotificationAction;
''', 1)
    if "case 'notificationAction':" not in text:
        text = text.replace("      case 'adState':\n        onAdState?.call(call.arguments == true);\n        break;\n", '''      case 'adState':
        onAdState?.call(call.arguments == true);
        break;
      case 'notificationAction':
        final action = call.arguments?.toString() ?? '';
        if (action.isNotEmpty) {
          await onNotificationAction?.call(action);
        }
        break;
''', 1)
    if 'Future<void> updateNotification({' not in text:
        text = text.replace('  Future<void> _autoplayPass() async {\n', '''  Future<void> updateNotification({
    required String title,
    required String artist,
    required String artwork,
    required bool playing,
  }) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('updateNotification', {
        'title': title,
        'artist': artist,
        'artwork': artwork,
        'playing': playing,
      });
    } catch (_) {}
  }

  Future<void> _autoplayPass() async {
''', 1)
    p.write_text(text)


def patch_sheet() -> None:
    path = 'lib/features/foryou/discovery_browser_sheet.dart'
    p = ROOT / path
    text = p.read_text()
    if "import 'dart:async';" not in text:
        text = "import 'dart:async';\n\n" + text
    if 'onNotificationAction:' not in text:
        text = text.replace('      onAdState: (on) => widget.controller.setAdActive(on),\n', '''      onAdState: (on) => widget.controller.setAdActive(on),
      onNotificationAction: (action) async {
        switch (action) {
          case 'toggle':
            await _togglePagePlayback();
            break;
          case 'next':
            VShotsPlaybackManager.instance.next();
            break;
          case 'previous':
            VShotsPlaybackManager.instance.previous();
            break;
          case 'stop':
            _close();
            break;
        }
      },
''', 1)
    if "_session.updateNotification(" not in text:
        text = text.replace('    widget.controller.setError(null);\n    await _session.load(url);\n', '''    widget.controller.setError(null);
    unawaited(
      _session.updateNotification(
        title: widget.controller.title ?? 'V Shots',
        artist: widget.controller.artist ?? 'Music playback',
        artwork: widget.controller.artwork ?? '',
        playing: true,
      ),
    );
    await _session.load(url);
''', 1)
    p.write_text(text)


if __name__ == '__main__':
    patch_main_audio_service()
    patch_native_browser()
    patch_session()
    patch_sheet()
    print('Interactive browser player notification patch applied.')

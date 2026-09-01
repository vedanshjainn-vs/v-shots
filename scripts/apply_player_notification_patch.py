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


def patch_native_browser() -> None:
    path = 'android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlatformView.kt'
    p = ROOT / path
    text = p.read_text()

    old_init = '''    init {
        setBackgroundColor(Color.BLACK)
'''
    new_init = '''    init {
        VShotsBrowserPlaybackService.eventChannel = events
        setBackgroundColor(Color.BLACK)
'''
    patch(path, old_init, new_init)

    old_set_state = '''    fun setMediaPlaying(value: Boolean) {
        if (mediaPlaying == value) return
        mediaPlaying = value
        if (value) {
            startPlaybackForegroundService()
        } else {
            stopPlaybackForegroundService()
        }
        events.invokeMethod("playbackState", value)
    }
'''
    new_set_state = '''    fun setMediaPlaying(value: Boolean) {
        if (mediaPlaying == value) {
            updatePlaybackNotification(value)
            return
        }
        mediaPlaying = value
        startPlaybackForegroundService(playing = value)
        events.invokeMethod("playbackState", value)
    }

    fun updateNotification(title: String, artist: String, playing: Boolean) {
        startPlaybackForegroundService(title = title, artist = artist, playing = playing)
    }
'''
    patch(path, old_set_state, new_set_state)

    old_start = '''    private fun startPlaybackForegroundService() {
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
'''
    new_start = '''    private fun startPlaybackForegroundService(
        title: String? = null,
        artist: String? = null,
        playing: Boolean = mediaPlaying,
    ) {
        val intent = Intent(appContext, VShotsBrowserPlaybackService::class.java).apply {
            action = VShotsBrowserPlaybackService.ACTION_UPDATE
            putExtra("title", title ?: this@VShotsBackgroundMediaWebView.url?.let { "V Shots" })
            putExtra("artist", artist ?: "Music playback")
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
'''
    patch(path, old_start, new_start)

    old_dispose = '''    fun disposeMedia() {
        stopPlaybackPolling()
        setMediaPlaying(false)
        stopLoading()
        loadUrl("about:blank")
    }
'''
    new_dispose = '''    fun disposeMedia() {
        stopPlaybackPolling()
        stopPlaybackForegroundService()
        if (VShotsBrowserPlaybackService.eventChannel === events) {
            VShotsBrowserPlaybackService.eventChannel = null
        }
        mediaPlaying = false
        stopLoading()
        loadUrl("about:blank")
    }
'''
    patch(path, old_dispose, new_dispose)

    old_case = '''                "setAdAssist" -> {
                    webView.setAdAssist((call.arguments as? Boolean) ?: true)
                    result.success(null)
                }
'''
    new_case = '''                "setAdAssist" -> {
                    webView.setAdAssist((call.arguments as? Boolean) ?: true)
                    result.success(null)
                }
                "updateNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    val title = args?.get("title")?.toString() ?: "V Shots"
                    val artist = args?.get("artist")?.toString() ?: "Music playback"
                    val playing = args?.get("playing") as? Boolean ?: true
                    webView.updateNotification(title, artist, playing)
                    result.success(null)
                }
'''
    patch(path, old_case, new_case)


def patch_session() -> None:
    path = 'lib/features/foryou/vshots_browser_session.dart'
    p = ROOT / path
    text = p.read_text()

    old_ctor = '''    this.onVideoEnded,
    this.onAdState,
    VShotsContentBlocker? contentBlocker,
'''
    new_ctor = '''    this.onVideoEnded,
    this.onAdState,
    this.onNotificationAction,
    VShotsContentBlocker? contentBlocker,
'''
    patch(path, old_ctor, new_ctor)

    old_fields = '''  final void Function(bool adActive)? onAdState;

  /// The general-purpose content blocker for this browser session.
'''
    new_fields = '''  final void Function(bool adActive)? onAdState;

  /// Android lock-screen/notification media actions. The sheet routes these
  /// back through VShotsPlaybackManager so there is still one queue owner.
  final Future<void> Function(String action)? onNotificationAction;

  /// The general-purpose content blocker for this browser session.
'''
    patch(path, old_fields, new_fields)

    old_handler = '''      case 'adState':
        onAdState?.call(call.arguments == true);
        break;
      case 'blocked':
'''
    new_handler = '''      case 'adState':
        onAdState?.call(call.arguments == true);
        break;
      case 'notificationAction':
        final action = call.arguments?.toString() ?? '';
        if (action.isNotEmpty) {
          await onNotificationAction?.call(action);
        }
        break;
      case 'blocked':
'''
    patch(path, old_handler, new_handler)

    anchor = '''  Future<void> _autoplayPass() async {
'''
    method = '''  Future<void> updateNotification({
    required String title,
    required String artist,
    required bool playing,
  }) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('updateNotification', {
        'title': title,
        'artist': artist,
        'playing': playing,
      });
    } catch (_) {}
  }

'''
    if 'Future<void> updateNotification({' not in text:
        if anchor not in text:
            raise SystemExit('session notification insertion anchor not found')
        text = text.replace(anchor, method + anchor, 1)
    p.write_text(text)


def patch_sheet() -> None:
    path = 'lib/features/foryou/discovery_browser_sheet.dart'
    p = ROOT / path
    text = p.read_text()

    old_session = '''      onAdState: (on) => widget.controller.setAdActive(on),
      // Player-essential hosts are ALWAYS allowed, so the general content
'''
    new_session = '''      onAdState: (on) => widget.controller.setAdActive(on),
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
      // Player-essential hosts are ALWAYS allowed, so the general content
'''
    patch(path, old_session, new_session)

    old_load = '''    widget.controller.setLoading(true);
    widget.controller.setError(null);
    await _session.load(url);
'''
    new_load = '''    widget.controller.setLoading(true);
    widget.controller.setError(null);
    unawaited(
      _session.updateNotification(
        title: widget.controller.title ?? 'V Shots',
        artist: widget.controller.artist ?? 'Music playback',
        playing: true,
      ),
    );
    await _session.load(url);
'''
    patch(path, old_load, new_load)

    p.write_text(text)


if __name__ == '__main__':
    patch_native_browser()
    patch_session()
    patch_sheet()
    print('Interactive browser player notification patch applied.')

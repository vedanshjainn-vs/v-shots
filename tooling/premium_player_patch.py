from pathlib import Path
import re


def read(path):
    return Path(path).read_text()


def write(path, text):
    Path(path).write_text(text)


def must_replace(path, old, new, label, count=1):
    p = Path(path)
    s = p.read_text()
    if old not in s:
        raise SystemExit(f'{label}: marker not found in {path}')
    s2 = s.replace(old, new, count)
    p.write_text(s2)

# 1) Controller: load the official YouTube embed instead of the full watch page.
p = 'lib/features/foryou/discovery_browser_controller.dart'
s = read(p)
if 'bool _audioMutedContent = false;' not in s:
    s = s.replace('  bool _adActive = false;\n', '  bool _adActive = false;\n  bool _audioMutedContent = false;\n', 1)
if 'bool get audioMutedContent' not in s:
    s = s.replace('  bool get adActive => _adActive;\n', '  bool get adActive => _adActive;\n  bool get audioMutedContent => _audioMutedContent;\n', 1)
s = s.replace('    _adActive = false;\n', '    _adActive = false;\n    _audioMutedContent = false;\n', 1)
old = '''  String? get url {
    final resolvedUrl = _track?['url'] as String?;
    if (resolvedUrl != null && resolvedUrl.isNotEmpty) return resolvedUrl;
    final id = videoId;
    if (id == null || id.isEmpty) return null;
    return youtubeWatchUrl(id);
  }'''
new = '''  String? get url {
    final resolvedUrl = _track?['url'] as String?;
    final resolvedId = resolvedUrl == null ? null : extractYoutubeVideoId(resolvedUrl);
    final id = resolvedId ?? videoId;
    if (id == null || id.isEmpty) {
      return resolvedUrl != null && resolvedUrl.isNotEmpty ? resolvedUrl : null;
    }
    return 'https://www.youtube.com/embed/$id?autoplay=1&playsinline=1&controls=1&rel=0&enablejsapi=1';
  }'''
if old in s:
    s = s.replace(old, new, 1)
marker = '''  void setAdActive(bool value) {
    if (_adActive == value) return;
    _adActive = value;
    debugPrint('[DiscoveryBrowser] adActive=$value');
    notifyListeners();
  }'''
if marker in s and 'void setAudioState(String state)' not in s:
    s = s.replace(marker, marker + '''

  void setAudioState(String state) {
    final muted = state == 'playing_muted_content';
    if (_audioMutedContent == muted) return;
    _audioMutedContent = muted;
    notifyListeners();
  }''', 1)
write(p, s)

# 2) Session: expose native audio state and explicit unmute+play.
p = 'lib/features/foryou/vshots_browser_session.dart'
s = read(p)
if 'onAudioStateChanged' not in s:
    s = s.replace('    this.onPlaybackStateChanged,\n    this.onNotificationAction,', '    this.onPlaybackStateChanged,\n    this.onAudioStateChanged,\n    this.onNotificationAction,', 1)
    s = s.replace('''  final void Function(VShotsPlaybackState state, bool playing)?
      onPlaybackStateChanged;

  final Future<void> Function(String action)? onNotificationAction;''', '''  final void Function(VShotsPlaybackState state, bool playing)?
      onPlaybackStateChanged;

  final void Function(String state)? onAudioStateChanged;

  final Future<void> Function(String action)? onNotificationAction;''', 1)
play_marker = '''  Future<void> play({bool userInitiated = true}) async {
    if (userInitiated) {
      _userPaused = false;
    }
    _autoplayPending = false;
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>(
        'play',
        <String, Object?>{'generation': _generation},
      );
    } catch (_) {}
  }'''
if play_marker in s and 'Future<void> unmuteAndPlay()' not in s:
    s = s.replace(play_marker, play_marker + '''

  Future<void> unmuteAndPlay() async {
    _userPaused = false;
    _autoplayPending = false;
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>(
        'unmuteAndPlay',
        <String, Object?>{'generation': _generation},
      );
    } catch (_) {}
  }''', 1)
old_event = '''      case 'adState':
        onAdState?.call(call.arguments == true);
        break;'''
new_event = '''      case 'adState':
        onAdState?.call(call.arguments == true);
        break;
      case 'audioState':
        if (_isCurrentEvent(call.arguments)) {
          final arguments = call.arguments;
          final state = arguments is Map
              ? arguments['state']?.toString() ?? ''
              : arguments?.toString() ?? '';
          if (state.isNotEmpty) onAudioStateChanged?.call(state);
        }
        break;'''
if old_event in s:
    s = s.replace(old_event, new_event, 1)
write(p, s)

# 3) Native WebView: make muted playback an explicit UI state, not a synthetic tap.
p = 'android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlatformView.kt'
s = read(p)
old = '''    private fun setAudioState(next: BrowserAudioState) {
        if (audioState == next) return
        Log.d(TAG, "audio state: $audioState -> $next")
        audioState = next
    }'''
new = '''    private fun setAudioState(next: BrowserAudioState) {
        if (audioState == next) return
        Log.d(TAG, "audio state: $audioState -> $next")
        audioState = next
        events.invokeMethod("audioState", mapOf(
            "state" to next.name.lowercase(Locale.US),
            "generation" to loadGeneration,
        ))
    }'''
if old in s:
    s = s.replace(old, new, 1)
# The old synthetic target is unreliable and can pause when the video surface receives the event.
s = s.replace("return 'unmute-target|' + String(targetX) + '|' + String(targetY);", "return 'muted-content';", 1)
# Replace only the first unmute-target branch body with a state notification.
start = s.find('                clean.startsWith("unmute-target|") -> {')
if start >= 0:
    end = s.find('\n                }', start)
    # Find the branch's closing brace by balancing braces.
    depth = 0
    i = start
    in_string = False
    while i < len(s):
        if s.startswith('{', i): depth += 1
        elif s.startswith('}', i):
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        i += 1
    branch = '''                clean == "muted-content" -> {
                    contentAudioValidationRequested = true
                    setAudioState(BrowserAudioState.PLAYING_MUTED_CONTENT)
                    setPlaybackState("playing", true)
                    Log.d(TAG, "content autoplay is muted; waiting for explicit sound action")
                }'''
    s = s[:start] + branch + s[end:]
# Add an explicit native unmute+play method if absent.
if 'fun unmuteAndPlay(requestedGeneration' not in s:
    marker = '    fun setVolume(volume: Double, requestedGeneration: Long? = null) {'
    idx = s.find(marker)
    if idx < 0:
        raise SystemExit('native setVolume marker not found')
    method = '''    fun unmuteAndPlay(requestedGeneration: Long? = null) {
        val generation = requestedGeneration ?: loadGeneration
        if (generation != loadGeneration || userPaused || adActive) return
        setNativeWebViewAudioMuted(false)
        evaluateJavascript(
            generationGuardedJs(
                """(function(){
                    try {
                        var v=document.querySelector('video,audio');
                        if(!v) return 'none';
                        v.muted=false;
                        v.volume=1.0;
                        var p=v.play();
                        if(p && p.catch){ p.catch(function(){}); }
                        return 'unmute-play-requested|'+(v.muted?'1':'0')+'|'+String(v.volume);
                    } catch(e) { return 'err'; }
                })()""",
                generation,
            )
        ) { result ->
            if (generation == loadGeneration) {
                contentAudioValidated = true
                Log.d(TAG, "explicit unmute+play: ${cleanJsResult(result)}")
            }
        }
    }

'''
    s = s[:idx] + method + s[idx:]
old = '''                "setVolume" -> {
                    // Audio-focus ducking: 0..1 on the real media element.'''
new = '''                "unmuteAndPlay" -> {
                    val generation = requestedGeneration(call.arguments)
                    if (generation == null || generation == webView.currentGeneration()) {
                        webView.unmuteAndPlay(generation)
                    }
                    result.success(null)
                }
                "setVolume" -> {
                    // Audio-focus ducking: 0..1 on the real media element.'''
if old in s:
    s = s.replace(old, new, 1)
old = '''        settings.mediaPlaybackRequiresUserGesture = false
        // Clear any application-level WebView mute before the first page.
        setNativeWebViewAudioMuted(false)
        settings.loadsImagesAutomatically = true'''
new = '''        settings.mediaPlaybackRequiresUserGesture = false
        settings.cacheMode = android.webkit.WebSettings.LOAD_DEFAULT
        settings.setSupportZoom(false)
        settings.builtInZoomControls = false
        settings.displayZoomControls = false
        setNativeWebViewAudioMuted(false)
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
        setLayerType(View.LAYER_TYPE_HARDWARE, null)
        settings.loadsImagesAutomatically = true'''
if old in s:
    s = s.replace(old, new, 1)
write(p, s)

# 4) Sheet: wire the audio-state event and add a safe explicit sound control.
p = 'lib/features/foryou/discovery_browser_sheet.dart'
s = read(p)
if 'onAudioStateChanged: widget.controller.setAudioState' not in s:
    s = s.replace('      onPlaybackStateChanged: widget.controller.setPlaybackState,\n      onError:', '      onPlaybackStateChanged: widget.controller.setPlaybackState,\n      onAudioStateChanged: widget.controller.setAudioState,\n      onError:', 1)
# Add a premium sound button immediately above the existing browser widget when the WebView reports muted content.
anchor = '              _session.buildWidget(),'
if anchor in s and 'Tap to turn sound on' not in s:
    overlay = '''              _session.buildWidget(),
              if (widget.controller.audioMutedContent)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await _session.unmuteAndPlay();
                          if (mounted) setState(() {});
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        icon: const Icon(Icons.volume_up_rounded, size: 19),
                        label: const Text('Tap to turn sound on', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ),'''
    s = s.replace(anchor, overlay, 1)
write(p, s)

print('premium player stabilization patch applied')

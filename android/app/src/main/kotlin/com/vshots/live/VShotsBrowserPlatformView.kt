package com.vshots.live

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.ByteArrayInputStream
import java.security.SecureRandom
import java.util.Locale

private const val VIEW_TYPE = "vshots/native_browser"
private const val TAG = "VShotsPlayback"

/**
 * V Shots native playback browser — OBSERVER + COMMAND EXECUTOR ONLY.
 *
 * This class deliberately makes NO playback policy decisions. It reports what
 * the real media element is doing, executes the explicit commands Flutter
 * sends, and publishes audio truth. Every "should it play / should it resume /
 * was that the user?" decision lives in exactly one place:
 * `lib/features/foryou/vshots_browser_session.dart`.
 *
 * WHAT CHANGED FROM THE PREVIOUS DESIGN (and why)
 * -----------------------------------------------
 *  • EVENT-DRIVEN MEDIA STATE. The old build ran a 1 Hz `evaluateJavascript`
 *    that scraped the whole document with `querySelector`, and a second
 *    position probe. That is gone. A one-shot bootstrap injected after page
 *    finish attaches real HTMLMediaElement listeners (`play`, `pause`,
 *    `playing`, `waiting`, `seeking`, `volumechange`, `timeupdate`, `ended`)
 *    and reports CHANGES through a token-guarded JS bridge. Java never polls
 *    the DOM for state.
 *
 *  • NO SYNTHETIC TOUCHES. The old "trusted unmute tap" fabricated
 *    down/up MotionEvents at computed coordinates and pushed them through
 *    `dispatchTouchEvent`. That is not a user gesture, it targeted a DOM node
 *    that YouTube can move, and it could land on the video body — which
 *    YouTube interprets as play/pause. Removed entirely.
 *
 *  • NO BLANKET TOUCH SWALLOWING. `dispatchTouchEvent` used to consume EVERY
 *    touch reaching the WebView, which fought Flutter's gesture arena and made
 *    the Discovery feed swipe unreliable. Removed. The video surface is now
 *    made inert INSIDE the page with a `pointer-events` shield, so Chromium
 *    hit-testing is correct, Flutter keeps its gestures, a tap on the video
 *    body cannot toggle playback, and YouTube's own unmute / ad-skip controls
 *    stay reachable because they are explicitly re-enabled.
 *
 *  • NO PAUSE-RECOVERY RETRY LOOP. The old `recoverUnexpectedPause()` called
 *    `play()` up to three times with debounce windows, fighting legitimate
 *    pauses. Removed; divergence is now reported honestly and corrected at
 *    most twice per load, by the Dart session.
 *
 *  • NO CONTENT MUTE LEAK. The old ad assist wrote `v.muted = true;
 *    v.volume = 0` and relied on a snapshot restore that could be skipped when
 *    playback was paused — which is how a SONG ended up silent with YouTube
 *    showing "tap to unmute". Ad muting is now an explicit, always-released
 *    flag owned by this class, cleared on ad end, on page finish and on load.
 */

/**
 * One-shot bootstrap. Installs the gesture shield and the media-event bridge.
 * Versions of this script are compiled HERE, never assembled from remote input.
 */
private fun bootstrapScript(token: String, generation: Long): String = """
(function(){
  var TOKEN = '$token';
  var GEN = $generation;
  function post(kind, payload){
    try {
      var body = { kind: kind, generation: GEN };
      if (payload) {
        for (var key in payload) {
          if (Object.prototype.hasOwnProperty.call(payload, key)) {
            body[key] = payload[key];
          }
        }
      }
      if (window.VShotsNative && window.VShotsNative.report) {
        window.VShotsNative.report(TOKEN, JSON.stringify(body));
      }
    } catch (e) {}
  }
  if (window.__vshotsBridgeGeneration === GEN) { post('ready', null); return 'installed'; }
  window.__vshotsBridgeGeneration = GEN;

  // ── Gesture routing shield ──────────────────────────────────────────────
  // The embedded player is a VIDEO SURFACE. Transport is owned by V Shots, so
  // a tap on the video body must not toggle playback. We express that as page
  // hit-testing (Chromium native behaviour) instead of intercepting touch at
  // the Android view layer, so Flutter's gesture arena is untouched and
  // vertical/horizontal swipes keep working.
  //
  // YouTube's own unmute control and skip-ad control stay interactive: they
  // are the only two controls the app deliberately delegates to YouTube.
  function installShield(){
    try {
      if (document.getElementById('vshots-gesture-shield')) return;
      var head = document.head || document.documentElement;
      if (!head) return;
      var style = document.createElement('style');
      style.id = 'vshots-gesture-shield';
      style.textContent = [
        '.html5-video-player, .html5-video-player * { pointer-events: none !important; }',
        '.ytp-unmute, .ytp-unmute *, .ytp-unmute-button, .ytp-unmute-button *',
        ' { pointer-events: auto !important; }',
        '.ytp-ad-skip-button, .ytp-ad-skip-button *',
        ' { pointer-events: auto !important; }',
        '.ytp-skip-ad-button, .ytp-skip-ad-button *',
        ' { pointer-events: auto !important; }',
        '.ytp-ad-skip-button-modern, .ytp-ad-skip-button-modern *',
        ' { pointer-events: auto !important; }'
      ].join('\n');
      head.appendChild(style);
    } catch (e) {}
  }

  function adActive(){
    try {
      if (document.querySelector('.ad-showing')) return true;
      var evidence = document.querySelector(
        '.ytp-ad-skip-button, .ytp-skip-ad-button,' +
        ' .ytp-ad-preview-container, .ytp-ad-text,' +
        ' .ytp-ad-duration-remaining'
      );
      if (!evidence) return false;
      var style = window.getComputedStyle(evidence);
      var rect = evidence.getBoundingClientRect();
      return style.display !== 'none' && style.visibility !== 'hidden' &&
             style.opacity !== '0' && rect.width > 0 && rect.height > 0;
    } catch (e) { return false; }
  }

  function nearEndOf(v){
    try {
      var d = v.duration;
      // Guard on a sane duration so a very short clip cannot report
      // "nearly finished" the moment it starts.
      return !v.paused && !v.ended && d && isFinite(d) && d > 3 &&
             v.currentTime >= d - 1.5;
    } catch (e) { return false; }
  }

  // Ad assist, official control only: click YouTube's OWN skip button when it
  // appears — exactly the action a user performs. Unskippable ads are never
  // interfered with. Gated on the remote flag pushed from Dart.
  function clickOfficialSkip(){
    if (window.__vshotsAdAssistEnabled === false) return;
    var selectors = ['button.ytp-ad-skip-button', 'button.ytp-skip-ad-button',
                     '.ytp-ad-skip-button-modern button',
                     'button.ytp-ad-skip-button-modern'];
    for (var i = 0; i < selectors.length; i++) {
      var b = document.querySelector(selectors[i]);
      if (b && b.offsetParent !== null && !b.disabled) {
        try { b.click(); } catch (e) {}
        return;
      }
    }
  }

  function describe(v){
    if (!v) return { state: 'loading', hasAudio: false };
    if (v.ended) return { state: 'ended', hasAudio: false };
    if (v.seeking || (!v.paused && v.readyState < 3)) {
      return { state: 'buffering', hasAudio: false };
    }
    if (v.paused) return { state: 'paused', hasAudio: false };
    var audible = !v.muted && (isFinite(v.volume) ? v.volume > 0 : true);
    // Audio truth is reported separately from transport truth: a running but
    // muted media element is NEVER advertised as audible playback.
    return {
      state: audible ? 'playing_with_audio' : 'playing_muted',
      hasAudio: audible
    };
  }

  var lastSignature = '';
  function publish(){
    try {
      var v = document.querySelector('video,audio');
      var body = describe(v);
      body.ad = adActive();
      // Near-end is part of the signature, so crossing the auto-advance
      // threshold produces exactly one report (not a per-tick stream).
      body.nearEnd = nearEndOf(v);
      var signature = body.state + '|' + (body.hasAudio ? '1' : '0') +
        '|' + (body.ad ? '1' : '0') + '|' + (body.nearEnd ? '1' : '0');
      if (signature === lastSignature) return;
      lastSignature = signature;
      post('transport', body);
    } catch (e) {}
  }

  function attach(){
    try {
      var v = document.querySelector('video,audio');
      if (!v) return false;
      if (v.__vshotsListenersAttached) { publish(); return true; }
      v.__vshotsListenersAttached = true;
      // `timeupdate` is what lets the near-end threshold be observed without
      // any Java-side polling.
      var events = ['play','pause','playing','waiting','seeking','seeked',
                    'volumechange','ended','loadedmetadata','durationchange',
                    'ratechange','timeupdate'];
      for (var i = 0; i < events.length; i++) {
        v.addEventListener(events[i], publish, true);
      }
      publish();
      return true;
    } catch (e) { return false; }
  }

  function position(){
    try {
      var v = document.querySelector('video,audio');
      if (!v) return;
      var duration = (v.duration && isFinite(v.duration))
        ? Math.round(v.duration * 1000) : -1;
      post('position', {
        positionMs: Math.round(v.currentTime * 1000),
        durationMs: duration
      });
    } catch (e) {}
  }

  installShield();
  attach();
  var attachAttempts = 0;
  var attachTimer = setInterval(function(){
    installShield();
    attachAttempts++;
    if (attach() || attachAttempts > 40) { clearInterval(attachTimer); }
  }, 250);

  // Page-local ad transition watcher. This runs inside the page (no Java round
  // trip) and reports CHANGE ONLY; it is not a state poll.
  var lastAd = adActive();
  var adTimer = setInterval(function(){
    var now = adActive();
    if (now !== lastAd) { lastAd = now; publish(); }
    // Only while an ad is on screen: use the official skip control. This
    // touches no playback state, never mutes, and stops being useful the
    // moment the ad ends.
    if (now) { clickOfficialSkip(); }
  }, 1000);

  // Position/scroll is published on a slow, read-only cadence so the media
  // session can render progress. One message per 5 s replaces the old
  // per-tick evaluateJavascript position probe.
  var positionTimer = setInterval(position, 5000);
  position();

  window.__vshotsDispose = function(){
    try { clearInterval(attachTimer); } catch (e) {}
    try { clearInterval(adTimer); } catch (e) {}
    try { clearInterval(positionTimer); } catch (e) {}
  };
  return 'bootstrapped';
})()
""".trimIndent()

/**
 * Reconciliation query — the ONLY remaining periodic evaluation.
 *
 * It is read-only, returns one short string, and cannot call play(), cannot
 * navigate, and cannot mutate the page. It exists purely so that a missed
 * media event cannot leave the app showing a stale state. A 5 s safety net is
 * not a state poll (the old design ran a full-document scrape every second
 * plus a separate position probe).
 */
private const val YT_RECONCILE_JS = """
(function(){
  try{
    var v = document.querySelector('video,audio');
    if(!v){ return 'none'; }
    var muted = v.muted ? '1' : '0';
    var volume = (v.volume !== undefined && isFinite(v.volume))
      ? String(v.volume) : '-1';
    var state;
    if(v.ended){ state = 'ended'; }
    else if(v.seeking || (!v.paused && v.readyState < 3)){ state = 'buffering'; }
    else if(v.paused){ state = 'paused'; }
    else {
      var audible = !v.muted && (isFinite(v.volume) ? v.volume > 0 : true);
      state = audible ? 'playing_with_audio' : 'playing_muted';
    }
    return state + '|' + muted + '|' + volume;
  }catch(e){ return 'none'; }
})()
""".trimIndent()

/** Mutes / unmutes ONLY the media element, for an in-stream ad. */
private fun adMuteScript(muted: Boolean, generation: Long): String {
    val value = if (muted) "true" else "false"
    return guardedScript(
        """
(function(){
  try{
    var v = document.querySelector('video,audio');
    if(!v){ return 'none'; }
    v.muted = $value;
    return 'ok';
  }catch(e){ return 'err'; }
})()
""".trimIndent(),
        generation,
    )
}

/**
 * Runs a mutating script only in the page generation that issued it. The
 * marker is installed after the matching page finishes, so a stale callback
 * can never alter a newly selected track.
 */
private fun guardedScript(script: String, generation: Long): String = """
(function(){
  if(window.__vshotsBridgeGeneration !== $generation){ return 'stale'; }
  return $script;
})()
""".trimIndent()

/** Explicit play/pause/seek/volume commands — the complete mutation surface. */
private fun transportScript(value: String, generation: Long): String =
    guardedScript(
        """
(function(){
  try{
    var v = document.querySelector('video,audio');
    if(!v){ return 'none'; }
    $value
    return 'ok';
  }catch(e){ return 'err'; }
})()
""".trimIndent(),
        generation,
    )

/** Explicit audio state: content audio and muted ads are never one boolean. */
private enum class BrowserAudioState {
    PLAYING_WITH_AUDIO,
    PLAYING_MUTED_AD,
    PLAYING_MUTED_CONTENT,
    PAUSED,
    BUFFERING,
    ENDED,
}

/** The wire vocabulary shared with `lib/features/foryou/vshots_playback_state.dart`. */
private enum class BrowserPlaybackState(val wire: String) {
    IDLE("idle"),
    LOADING("loading"),
    BUFFERING("buffering"),
    PLAYING_MUTED("playing_muted"),
    PLAYING_WITH_AUDIO("playing_with_audio"),
    PAUSED_BY_USER("paused_by_user"),
    PAUSED_BY_AUDIO_FOCUS("paused_by_audio_focus"),
    PAUSED_BY_LIFECYCLE("paused_by_lifecycle"),
    PAUSED_BY_BROWSER("paused_by_browser"),
    ENDED("ended"),
    ERROR("error"),
}

private fun requestedGeneration(arguments: Any?): Long? {
    return ((arguments as? Map<*, *>)?.get("generation") as? Number)?.toLong()
}

/**
 * Convert a supported YouTube watch/share URL to the official embedded-player
 * surface. The WebView must never render the watch page around the media: V
 * Shots owns the header, metadata, controls, queue, and gestures. The embed
 * is still the official YouTube player and keeps the media element/MediaSession
 * path used by the existing playback engine.
 */
private fun youtubeVideoId(url: String): String? {
    return try {
        val uri = Uri.parse(url)
        val host = uri.host?.lowercase(Locale.US) ?: return null
        val candidate = when {
            host == "youtu.be" || host.endsWith(".youtu.be") ->
                uri.pathSegments.firstOrNull()
            host == "youtube.com" || host.endsWith(".youtube.com") -> {
                uri.getQueryParameter("v") ?: run {
                    val segments = uri.pathSegments
                    if (segments.size >= 2 &&
                        segments[0] in setOf("embed", "shorts", "live")
                    ) {
                        segments[1]
                    } else {
                        null
                    }
                }
            }
            else -> null
        }
        candidate?.takeIf { Regex("^[A-Za-z0-9_-]{6,20}$").matches(it) }
    } catch (_: Throwable) {
        null
    }
}

private fun youtubePlayerSurfaceUrl(url: String, autoplay: Boolean): String {
    val id = youtubeVideoId(url) ?: return url
    val autoplayValue = if (autoplay) 1 else 0
    return "https://www.youtube.com/embed/$id" +
        "?autoplay=$autoplayValue&playsinline=1&controls=0&rel=0" +
        "&modestbranding=1&iv_load_policy=3&enablejsapi=1&fs=0" +
        "&disablekb=1"
}

/**
 * Discovery-only native browser view.
 *
 * Third-party ad blocking for non-YouTube pages. Official YouTube embedded-player
 * resources (including YouTube ads) are never intercepted or hidden.
 *
 * Unlike the generic webview_flutter platform view, this WebView deliberately
 * keeps its media lifecycle alive when Android makes the Flutter activity
 * invisible. This is the critical part for long-form audio/video continuity
 * while the Discovery browser is minimized, backgrounded, or the screen is
 * locked.
 */
private class VShotsBackgroundMediaWebView(
    context: Context,
    private val events: MethodChannel,
) : WebView(context) {

    private val appContext = context.applicationContext
    private val handler = Handler(Looper.getMainLooper())

    /** Bridges page-side media events back to Java without polling the DOM. */
    private inner class MediaBridge {
        @JavascriptInterface
        fun report(token: String, payload: String) {
            if (token != bridgeToken) {
                Log.w(TAG, "rejected bridge report with an unknown token")
                return
            }
            handler.post { handleBridgePayload(payload) }
        }
    }

    /** Per-WebView secret embedded only inside our injected closure. */
    private val bridgeToken: String = run {
        val bytes = ByteArray(16)
        SecureRandom().nextBytes(bytes)
        bytes.joinToString("") { String.format(Locale.US, "%02x", it) }
    }

    /** Monotonic load generation. Every async callback captures it so a stale
     *  page cannot mutate the next track's state. */
    private var loadGeneration = 0L
    private var currentLoadUrl = ""
    private var playbackState = BrowserPlaybackState.IDLE
    private var notificationTitle = "V Shots"
    private var notificationArtist = "Music playback"
    private var notificationArtwork = ""

    /**
     * Flutter keeps this platform view mounted at a constant size while the
     * player is collapsed, but the view can still receive INVISIBLE/window
     * pause callbacks while it is translated below the mini-player. Those
     * callbacks are a view-lifecycle signal, not a playback command. Keep the
     * WebView media lifecycle retained for the lifetime of this session; the
     * explicit JS pause command remains the only way playback is paused by
     * this class. The flag is cleared only during disposal.
     */
    private var retainMediaLifecycle = true

    // ── FORCEFUL Ad Blocker State ──────────────────────────────────────────
    // ALWAYS ON by default. Populated from Dart via "setContentBlocker".
    // Host-exact + suffix matching + URL pattern matching.
    // Essential/allow hosts always pass (media must never be blocked).
    private var blockerEnabled = true
    private val blockedHosts = mutableSetOf<String>()
    private val essentialHosts = mutableSetOf<String>()
    private val adUrlPatterns = mutableListOf<String>()

    private var popupBlockedCount = 0

    // ── Playback observation state ─────────────────────────────────────────

    /** True while the YouTube page is playing an in-stream ad. */
    private var adActive = false

    /** Completion is reported at most once per load. The manager decides
     *  whether a completion means "advance". */
    private var videoEndedReported = false

    /** Explicit audio state. A muted advertisement is never represented as a
     *  muted content boolean, so content restoration has a single owner. */
    private var audioState = BrowserAudioState.PAUSED

    /** The ONE reason this class may pause: an explicit command from Flutter. */
    private var lastPauseOrigin = "browser"

    /** True while WE muted the media element for an advertisement. */
    private var adMuted = false

    /** Master switch for the ad assist. Pushed from Dart
     *  (`enable_youtube_ad_assist` remote flag). */
    private var adAssistEnabled = true

    var mediaPlaying: Boolean = false
        private set

    /**
     * Low-frequency, read-only reconciliation. Catches a missed page event;
     * never mutates, never navigates, never calls play().
     */
    private val reconcilePoll = object : Runnable {
        override fun run() {
            if (!isAttachedToWindow && !mediaPlaying) return
            val generation = loadGeneration
            evaluateJavascript(YT_RECONCILE_JS) { result ->
                if (generation == loadGeneration) {
                    handleReconcile(cleanJsResult(result), generation)
                }
            }
            handler.postDelayed(this, 5000L)
        }
    }

    private fun setAudioState(next: BrowserAudioState) {
        if (audioState == next) return
        Log.d(TAG, "audio state: $audioState -> $next")
        audioState = next
    }

    /** Keep the entire WebView unmuted at the native WebView layer. */
    private fun setNativeWebViewAudioMuted(muted: Boolean) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.MUTE_AUDIO)) return
        try {
            WebViewCompat.setAudioMuted(this, muted)
        } catch (_: Throwable) {
            // Older System WebView providers may not expose this feature.
        }
    }

    // ── Bridge ingestion ───────────────────────────────────────────────────

    private fun handleBridgePayload(payload: String) {
        val json = try {
            org.json.JSONObject(payload)
        } catch (_: Throwable) {
            return
        }
        val generation = json.optLong("generation", -1L)
        if (generation >= 0 && generation != loadGeneration) return
        when (json.optString("kind")) {
            "ready" -> Unit
            "transport" -> {
                setAdActive(json.optBoolean("ad", adActive))
                val observed = json.optString("state", "idle")
                applyObservedState(
                    observed,
                    json.optBoolean("hasAudio", false),
                    generation = loadGeneration,
                )
                // Seamless auto-advance: the validated near-end point fires the
                // completion once, exactly like a natural end. The Flutter
                // manager owns what happens next.
                if (observed == "ended" || json.optBoolean("nearEnd", false)) {
                    reportVideoEnded()
                }
            }
            "position" -> {
                val positionMs = json.optLong("positionMs", -1L)
                val durationMs = json.optLong("durationMs", -1L)
                if (positionMs >= 0) {
                    VShotsBrowserPlaybackService.updatePositionFromBrowser(
                        positionMs = positionMs,
                        durationMs = durationMs,
                        generation = loadGeneration,
                    )
                    events.invokeMethod(
                        "position",
                        mapOf(
                            "positionMs" to positionMs,
                            "durationMs" to durationMs,
                            "generation" to loadGeneration,
                        ),
                    )
                }
            }
        }
    }

    private fun handleReconcile(result: String, generation: Long) {
        if (generation != loadGeneration || result == "none") return
        val parts = result.split("|")
        val state = parts.firstOrNull().orEmpty()
        if (state.isEmpty()) return
        val muted = parts.getOrNull(1) == "1"
        val volume = parts.getOrNull(2)?.toDoubleOrNull() ?: 1.0
        applyObservedState(
            state,
            hasAudio = !muted && volume > 0.0,
            generation = generation,
        )
    }

    /**
     * Converts one observed media state into the shared vocabulary and
     * publishes it. The pause ORIGIN is reported, never invented: the Dart
     * session is the only layer that decides what a pause means.
     */
    private fun applyObservedState(
        observed: String,
        hasAudio: Boolean,
        generation: Long,
    ) {
        if (generation != loadGeneration) return
        when (observed) {
            "playing_with_audio" -> {
                setAdActive(false)
                setAudioState(
                    if (hasAudio) BrowserAudioState.PLAYING_WITH_AUDIO
                    else BrowserAudioState.PLAYING_MUTED_CONTENT,
                )
                setPlaybackState(
                    if (hasAudio) BrowserPlaybackState.PLAYING_WITH_AUDIO
                    else BrowserPlaybackState.PLAYING_MUTED,
                    playing = true,
                )
            }
            "playing_muted" -> {
                setAudioState(
                    if (adActive) BrowserAudioState.PLAYING_MUTED_AD
                    else BrowserAudioState.PLAYING_MUTED_CONTENT,
                )
                setPlaybackState(BrowserPlaybackState.PLAYING_MUTED, playing = true)
            }
            "buffering" -> {
                setAudioState(BrowserAudioState.BUFFERING)
                setPlaybackState(BrowserPlaybackState.BUFFERING, playing = mediaPlaying)
            }
            "paused" -> {
                setAudioState(BrowserAudioState.PAUSED)
                setPlaybackState(pauseStateForOrigin(), playing = false)
            }
            "ended" -> {
                setAudioState(BrowserAudioState.ENDED)
                setPlaybackState(BrowserPlaybackState.ENDED, playing = false)
            }
            "loading" -> setPlaybackState(BrowserPlaybackState.LOADING, playing = false)
            else -> Unit
        }
    }

    /** The pause state that matches the last command Flutter issued. */
    private fun pauseStateForOrigin(): BrowserPlaybackState = when (lastPauseOrigin) {
        "user" -> BrowserPlaybackState.PAUSED_BY_USER
        "focus" -> BrowserPlaybackState.PAUSED_BY_AUDIO_FOCUS
        "lifecycle" -> BrowserPlaybackState.PAUSED_BY_LIFECYCLE
        else -> BrowserPlaybackState.PAUSED_BY_BROWSER
    }

    private fun reportVideoEnded() {
        if (videoEndedReported) return
        videoEndedReported = true
        Log.d(TAG, "media completion reported")
        events.invokeMethod("videoEnded", mapOf("generation" to loadGeneration))
    }

    private fun setAdActive(value: Boolean) {
        if (adActive == value) return
        adActive = value
        Log.d(TAG, if (value) "in-stream ad started" else "in-stream ad ended")
        events.invokeMethod("adState", value)
        if (value) {
            if (adAssistEnabled) muteAdForAssist()
        } else {
            // Releasing our ad mute is unconditional: a song must never be left
            // silent because an ad ended while a command was in flight.
            releaseAdMute()
        }
    }

    /**
     * YouTube AD ASSIST — uses ONLY the official player's own state:
     *
     *   1. While an in-stream ad plays, the ad is muted (the app's music must
     *      not blast ad audio between songs).
     *   2. When YouTube shows its own Skip button, it is clickable — the
     *      gesture shield explicitly re-enables it. Unskippable ads are never
     *      interfered with: they play (muted) in full.
     *   3. Nothing is blocked, hidden, resized or sped up. No ad-network
     *      interception, no unofficial APIs, no stream access.
     *
     * Gated by `enable_youtube_ad_assist` (remote flag, default ON).
     */
    private fun muteAdForAssist() {
        if (adMuted) return
        val generation = loadGeneration
        adMuted = true
        evaluateJavascript(adMuteScript(true, generation)) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            Log.d(TAG, "ad muted: ${cleanJsResult(result)}")
        }
    }

    private fun releaseAdMute() {
        if (!adMuted) return
        adMuted = false
        val generation = loadGeneration
        evaluateJavascript(adMuteScript(false, generation)) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            Log.d(TAG, "ad mute released: ${cleanJsResult(result)}")
        }
    }

    init {
        VShotsBrowserPlaybackService.eventChannel = events
        setBackgroundColor(Color.BLACK)
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        // Chromium autoplay policy: the app drives playback from an explicit
        // command path, so the WebView must not require a synthetic gesture.
        settings.mediaPlaybackRequiresUserGesture = false
        settings.cacheMode = WebSettings.LOAD_DEFAULT
        settings.setSupportZoom(false)
        settings.builtInZoomControls = false
        settings.displayZoomControls = false
        // Clear any application-level WebView mute before the first page.
        setNativeWebViewAudioMuted(false)
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
        setLayerType(View.LAYER_TYPE_HARDWARE, null)
        settings.loadsImagesAutomatically = true
        settings.javaScriptCanOpenWindowsAutomatically = false
        settings.setSupportMultipleWindows(false) // Block popup windows
        addJavascriptInterface(MediaBridge(), "VShotsNative")

        webChromeClient = object : WebChromeClient() {
            // Override to block popup windows completely
            override fun onCreateWindow(
                view: WebView?,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: android.os.Message?
            ): Boolean {
                popupBlockedCount++
                events.invokeMethod("blocked", "popup-window")
                return false
            }
        }

        webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                if (!isCurrentPage(url)) return
                lastPauseOrigin = "browser"
                events.invokeMethod("pageStarted", mapOf("generation" to loadGeneration))
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                if (!isCurrentPage(url)) return
                val generation = loadGeneration
                // The bridge must exist before the media element does. If it
                // does not install, the page simply reports nothing and the
                // reconciliation poll keeps the app consistent.
                evaluateJavascript(bootstrapScript(bridgeToken, generation)) { result ->
                    if (generation != loadGeneration) return@evaluateJavascript
                    Log.d(TAG, "bootstrap: ${cleanJsResult(result)}")
                }
                events.invokeMethod("pageFinished", mapOf("generation" to generation))
                startReconcilePolling()
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?,
            ) {
                if (request?.isForMainFrame != false && isCurrentPage(request?.url?.toString())) {
                    events.invokeMethod(
                        "error",
                        mapOf(
                            "message" to "Playback failed — please retry",
                            "generation" to loadGeneration,
                        ),
                    )
                }
            }

            /**
             * A dead renderer process must not take the app down (the default
             * is to crash the whole process). Returning true means "we handled
             * it": the session tears the platform view down and remounts a
             * fresh one exactly once for this load.
             */
            override fun onRenderProcessGone(
                view: WebView?,
                detail: RenderProcessGoneDetail?,
            ): Boolean {
                Log.w(TAG, "WebView renderer gone (crashed=${detail?.didCrash()})")
                stopReconcilePolling()
                retainMediaLifecycle = false
                mediaPlaying = false
                playbackState = BrowserPlaybackState.ERROR
                events.invokeMethod(
                    "error",
                    mapOf(
                        "message" to "Playback was interrupted — please retry",
                        "reason" to "renderer-gone",
                        "generation" to loadGeneration,
                    ),
                )
                return true
            }

            /**
             * NETWORK-LEVEL AD BLOCKING — Primary defense.
             * Intercepts ALL resource requests and blocks ads before they load.
             * Runs on BACKGROUND thread — never touch MethodChannel directly.
             */
            override fun shouldInterceptRequest(
                view: WebView?,
                request: WebResourceRequest?,
            ): WebResourceResponse? {
                return try {
                    val url = request?.url ?: return null
                    val urlStr = url.toString()

                    // Fast path: blocker disabled
                    if (!blockerEnabled) return null

                    val host = url.host?.lowercase(Locale.US) ?: return null
                    val path = url.path?.lowercase(Locale.US) ?: ""
                    val query = url.query?.lowercase(Locale.US) ?: ""

                    // YouTube (and Google ad CDNs used by the official embedded player)
                    // must never be intercepted — no ad-resource blocking.
                    if (isYouTubeDomain(host) || isYouTubeAdNetwork(host)) return null

                    // Essential hosts are NEVER blocked
                    if (matchesAnyHost(host, essentialHosts)) return null

                    // Host-based blocking
                    if (matchesAnyHost(host, blockedHosts)) {
                        reportBlock(host)
                        return emptyResponse()
                    }

                    // URL pattern blocking (catches ad paths, VAST/VPAID, etc.)
                    if (matchesAdPattern(urlStr, path, query)) {
                        reportBlock(host)
                        return emptyResponse()
                    }

                    // Allow everything else
                    null
                } catch (t: Throwable) {
                    // A blocker error must NEVER crash the WebView
                    null
                }
            }

            /**
             * Check if host is a YouTube domain.
             */
            private fun isYouTubeDomain(host: String): Boolean {
                val youtubeDomains = listOf(
                    "youtube.com",
                    "www.youtube.com",
                    "m.youtube.com",
                    "youtube-nocookie.com",
                    "youtu.be",
                    "ytimg.com",
                    "yt3.ggpht.com",
                    "yt3.googleusercontent.com",
                    "youtube-ui.l.google.com",
                    "youtubeembedded-pa.googleapis.com",
                    "youtube.googleapis.com",
                    "s.youtube.com",
                    "googlevideo.com",
                )
                return youtubeDomains.any { host == it || host.endsWith(".$it") }
            }

            /** Google ad CDNs used by the official embedded player — never blocked. */
            private fun isYouTubeAdNetwork(host: String): Boolean {
                val networks = listOf(
                    "doubleclick.net",
                    "googlesyndication.com",
                    "googleadservices.com",
                    "adservice.google.com",
                    "adservice.google.co.in",
                    "adservice.google.co.uk",
                )
                return networks.any { host == it || host.endsWith(".$it") }
            }

            /**
             * URL NAVIGATION BLOCKING — Blocks ad redirects/popups.
             * Intercepts navigation attempts before they happen.
             */
            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?,
            ): Boolean {
                val url = request?.url ?: return false
                val host = url.host?.lowercase(Locale.US) ?: return false
                val urlStr = url.toString()
                val path = url.path?.lowercase(Locale.US) ?: ""
                val query = url.query?.lowercase(Locale.US) ?: ""

                // Never intercept YouTube navigation or YouTube ad-network hosts.
                if (isYouTubeDomain(host) || isYouTubeAdNetwork(host)) return false

                // Allow essential hosts
                if (isAllowedHost(host)) return false

                // Block ad domains
                if (matchesAnyHost(host, blockedHosts)) {
                    reportBlock(host)
                    return true
                }

                // Block ad URL patterns in navigation
                if (matchesAdPattern(urlStr, path, query)) {
                    reportBlock(host)
                    return true
                }

                // Block suspicious redirects (non-HTTPS, data: URIs, javascript:)
                val scheme = url.scheme?.lowercase(Locale.US) ?: ""
                if (scheme != "https" && scheme != "http" && scheme != "javascript") {
                    if (scheme == "intent" || scheme == "market" || scheme == "tel" || scheme == "mailto") {
                        return false // Allow legitimate deep links
                    }
                    reportBlock("suspicious-scheme:$scheme")
                    return true
                }

                return false
            }
        }
    }

    /** Host == rule or endsWith ".rule" (e.g. "doubleclick.net" also matches
     *  "ad.doubleclick.net"). Conservative: no substring matching. */
    private fun matchesAnyHost(host: String, rules: Set<String>): Boolean {
        for (rule in rules) {
            if (host == rule || host.endsWith(".$rule")) return true
        }
        return false
    }

    /**
     * Check if URL matches known ad patterns (paths, queries, VAST/VPAID).
     * This catches ads served from legitimate domains via specific paths.
     */
    private fun matchesAdPattern(url: String, path: String, query: String): Boolean {
        val lowerUrl = url.lowercase(Locale.US)
        val lowerPath = path.lowercase(Locale.US)
        val lowerQuery = query.lowercase(Locale.US)

        for (pattern in adUrlPatterns) {
            val lowerPattern = pattern.lowercase(Locale.US)
            if (lowerPath.contains(lowerPattern) || lowerUrl.contains(lowerPattern)) {
                return true
            }
        }

        // VAST/VMAP/VPAID checks (only for non-YouTube hosts)
        if (lowerPath.contains("/vast") ||
            lowerPath.contains("/vmap") ||
            lowerPath.contains("/vpaid") ||
            lowerQuery.contains("vast") ||
            lowerQuery.contains("vmap") ||
            lowerQuery.contains("vpaid")
        ) {
            // Don't block YouTube's internal VAST handling
            if (!lowerUrl.contains("youtube.com") && !lowerUrl.contains("youtu.be")) {
                return true
            }
        }

        return false
    }

    private fun isDeniedJioHost(host: String): Boolean {
        val h = host.lowercase(Locale.US)
        if (h == "api.jiosaavn.com" || h.endsWith(".api.jiosaavn.com")) return true
        if (h == "saavn.me" || h.endsWith(".saavn.me")) return true
        return false
    }

    private fun isAllowedHost(host: String): Boolean {
        val h = host.lowercase(Locale.US)
        if (isDeniedJioHost(h)) return false
        val allowed = listOf(
            "youtube.com",
            "youtu.be",
            "youtube-nocookie.com",
            "googlevideo.com",
            "ytimg.com",
            "google.com",
            "googleapis.com",
            "gstatic.com",
            "ggpht.com",
            "googleusercontent.com",
            "accounts.google.com",
            "play.google.com",
            "cloudflare.com",
            "supabase.co",
            "jiosaavn.com",
            "www.jiosaavn.com",
            "saavn.com",
            "www.saavn.com",
            "static.saavncdn.com",
            "c.saavncdn.com",
        )
        return allowed.any { h == it || h.endsWith(".$it") }
    }

    private fun reportBlock(host: String) {
        val hostCopy = host
        handler.post { events.invokeMethod("blocked", hostCopy) }
    }

    private fun emptyResponse(): WebResourceResponse {
        return WebResourceResponse(
            "text/plain",
            "utf-8",
            ByteArrayInputStream(ByteArray(0)),
        )
    }

    private fun isCurrentPage(callbackUrl: String?): Boolean {
        if (callbackUrl.isNullOrEmpty() || currentLoadUrl.isEmpty()) return true
        if (callbackUrl == currentLoadUrl) return true
        val expected = Uri.parse(currentLoadUrl)
        val actual = Uri.parse(callbackUrl)
        val expectedVideo = expected.getQueryParameter("v")
        return if (!expectedVideo.isNullOrEmpty()) {
            callbackUrl.contains("v=$expectedVideo") ||
                callbackUrl.contains("/embed/$expectedVideo")
        } else {
            actual.host == expected.host
        }
    }

    fun load(url: String, requestedGeneration: Long? = null, autoplay: Boolean = true) {
        if (!url.startsWith("https://")) return
        val requestedHost = Uri.parse(url).host?.lowercase(Locale.US) ?: return
        if (isDeniedJioHost(requestedHost)) return
        if (requestedGeneration != null && requestedGeneration < loadGeneration) return
        val playbackUrl = youtubePlayerSurfaceUrl(url, autoplay)
        loadGeneration = requestedGeneration ?: (loadGeneration + 1L)
        currentLoadUrl = playbackUrl
        adActive = false
        adMuted = false
        videoEndedReported = false
        lastPauseOrigin = if (autoplay) "browser" else "user"
        mediaPlaying = false
        setAudioState(
            if (autoplay) BrowserAudioState.BUFFERING else BrowserAudioState.PAUSED
        )
        setNativeWebViewAudioMuted(false)
        setPlaybackState(BrowserPlaybackState.LOADING, playing = false)
        // Cancel the previous document before starting a new generation. This
        // prevents late callbacks from the old navigation from becoming the
        // new track's page-finished/autoplay signal.
        stopLoading()
        stopReconcilePolling()

        // YouTube requires embedded-player clients in a WebView to identify
        // themselves with an HTTP Referer. Android WebView sends no Referer
        // for a direct load by default, which produces player Error 153. Use
        // the installed Android application ID as the stable app identity,
        // exactly as YouTube's embedded-player requirements specify. JioSaavn
        // loads remain unchanged and receive no YouTube header.
        val additionalHeaders: Map<String, String> = if (youtubeVideoId(url) != null) {
            mapOf(
                "Referer" to "https://${appContext.packageName.lowercase(Locale.US)}",
            )
        } else {
            emptyMap()
        }
        loadUrl(playbackUrl, additionalHeaders)
    }

    /** Toggles the YouTube ad assist (remote flag from Dart). */
    fun setAdAssist(enabled: Boolean) {
        adAssistEnabled = enabled
        if (!enabled) releaseAdMute()
        // The page-local ad watcher reads this so the official skip click can
        // be disabled without another JS injection.
        try {
            evaluateJavascript(
                "window.__vshotsAdAssistEnabled = $enabled;",
                null,
            )
        } catch (_: Throwable) {
            // Flag propagation is best effort.
        }
        Log.d(TAG, "ad assist ${if (enabled) "enabled" else "disabled"}")
    }

    /** Applies the compiled blocker configuration from Dart. Cheap sets only —
     *  no regex, no list reloads. Does NOT recreate the WebView. */
    fun setContentBlocker(
        enabled: Boolean,
        blocked: List<String>,
        essential: List<String>,
        patterns: List<String> = emptyList(),
    ) {
        blockerEnabled = enabled
        blockedHosts.clear()
        blockedHosts.addAll(blocked.map { it.lowercase(Locale.US) })
        essentialHosts.clear()
        essentialHosts.addAll(essential.map { it.lowercase(Locale.US) })
        adUrlPatterns.clear()
        adUrlPatterns.addAll(patterns)
    }

    private fun setPlaybackState(state: BrowserPlaybackState, playing: Boolean) {
        val changed = playbackState != state || mediaPlaying != playing
        playbackState = state
        mediaPlaying = playing
        if (!changed) return
        startPlaybackForegroundService(playing = playing, state = state.wire)
        events.invokeMethod(
            "playbackState",
            mapOf(
                "playing" to playing,
                "state" to state.wire,
                "hasAudio" to (state == BrowserPlaybackState.PLAYING_WITH_AUDIO),
                "generation" to loadGeneration,
            ),
        )
    }

    fun updateNotification(title: String, artist: String, artwork: String, playing: Boolean) {
        notificationTitle = title
        notificationArtist = artist
        notificationArtwork = artwork
        // Metadata updates use the authoritative native state. The Dart flag
        // is intentionally not allowed to request play or audio focus.
        startPlaybackForegroundService(
            title = notificationTitle,
            artist = notificationArtist,
            artwork = notificationArtwork,
            playing = mediaPlaying,
            state = playbackState.wire,
        )
    }

    private fun startReconcilePolling() {
        handler.removeCallbacks(reconcilePoll)
        handler.post(reconcilePoll)
    }

    private fun stopReconcilePolling() {
        handler.removeCallbacks(reconcilePoll)
    }

    private fun startPlaybackForegroundService(
        title: String? = null,
        artist: String? = null,
        artwork: String? = null,
        playing: Boolean = mediaPlaying,
        positionMs: Long = -1L,
        durationMs: Long = -1L,
        state: String = playbackState.wire,
        userCommand: String? = null,
    ) {
        val intent = Intent(appContext, VShotsBrowserPlaybackService::class.java).apply {
            action = VShotsBrowserPlaybackService.ACTION_UPDATE
            putExtra("title", title ?: notificationTitle)
            putExtra("artist", artist ?: notificationArtist)
            putExtra("artwork", artwork ?: notificationArtwork)
            putExtra("playing", playing)
            putExtra("state", state)
            putExtra("generation", loadGeneration)
            if (userCommand != null) putExtra("userCommand", userCommand)
            putExtra("positionMs", positionMs)
            putExtra("durationMs", durationMs)
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

    private fun stopPlaybackForegroundService() {
        try {
            appContext.stopService(
                Intent(appContext, VShotsBrowserPlaybackService::class.java),
            )
        } catch (_: Exception) {
            // Best effort only.
        }
    }

    fun currentGeneration(): Long = loadGeneration

    private fun runPauseCommand(generation: Long) {
        val body = "v.pause();"
        evaluateJavascript(transportScript(body, generation)) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            Log.d(TAG, "command: ${cleanJsResult(result)}")
        }
    }

    fun seekBy(seconds: Int, requestedGeneration: Long? = null) {
        val generation = requestedGeneration ?: loadGeneration
        if (generation != loadGeneration) return
        val body = """
          var d=(v.duration&&isFinite(v.duration))?v.duration:null;
          var t=v.currentTime+($seconds);
          if(d!=null){t=Math.max(0,Math.min(d,t));}else{t=Math.max(0,t);}
          v.currentTime=t;
        """.trimIndent()
        evaluateJavascript(transportScript(body, generation)) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            Log.d(TAG, "seek: ${cleanJsResult(result)}")
        }
    }

    fun seekTo(positionMs: Long, requestedGeneration: Long? = null) {
        val generation = requestedGeneration ?: loadGeneration
        if (generation != loadGeneration || positionMs < 0L) return
        val body = """
          var target=$positionMs/1000;
          if(v.duration && isFinite(v.duration)){
            target=Math.max(0,Math.min(v.duration,target));
          }else{
            target=Math.max(0,target);
          }
          v.currentTime=target;
        """.trimIndent()
        evaluateJavascript(transportScript(body, generation)) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            Log.d(TAG, "seekTo: ${cleanJsResult(result)}")
        }
    }

    /** Audio-focus ducking only. It never changes the transport. */
    fun setVolume(volume: Double, requestedGeneration: Long? = null) {
        val generation = requestedGeneration ?: loadGeneration
        if (generation != loadGeneration) return
        val body = """
          v.volume=$volume;
        """.trimIndent()
        evaluateJavascript(transportScript(body, generation)) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            Log.d(TAG, "volume: ${cleanJsResult(result)}")
        }
    }

    /**
     * Explicit PAUSE. [origin] is one of `user`, `focus`, `lifecycle` and is
     * reported back with the resulting pause so the Dart session can classify
     * it correctly instead of guessing.
     */
    fun pauseMedia(
        origin: String,
        requestedGeneration: Long? = null,
        userInitiated: Boolean = true,
    ) {
        val generation = requestedGeneration ?: loadGeneration
        if (generation != loadGeneration) return
        lastPauseOrigin = origin
        setAudioState(BrowserAudioState.PAUSED)
        runPauseCommand(generation)
        setPlaybackState(pauseStateForOrigin(), playing = false)
        if (userInitiated) {
            startPlaybackForegroundService(
                playing = false,
                state = pauseStateForOrigin().wire,
                userCommand = "pause",
            )
        }
    }

    /** Explicit PLAY. Acquires audio focus and clears native mute first. */
    fun userPlay(requestedGeneration: Long? = null) {
        val generation = requestedGeneration ?: loadGeneration
        if (generation != loadGeneration) return
        lastPauseOrigin = "browser"
        // Acquire audio focus and clear native WebView mute BEFORE play.
        VShotsBrowserPlaybackService.prepareForPlayback()
        setNativeWebViewAudioMuted(false)
        startPlaybackForegroundService(
            playing = mediaPlaying,
            state = playbackState.wire,
            userCommand = "play",
        )
        val body = """
          v.play();
        """.trimIndent()
        evaluateJavascript(transportScript(body, generation)) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            // "ok" only means HTMLMediaElement.play() was invoked. Its Promise
            // can still be rejected, so the OBSERVED media events remain the
            // single source of playback truth. Nothing is reported as playing
            // from here.
            Log.d(TAG, "explicit play: ${cleanJsResult(result)}")
        }
    }

    private fun cleanJsResult(result: String?): String {
        return result.orEmpty().trim().trim('"').lowercase(Locale.US)
    }

    /** Keep the WebView media lifecycle alive across Android visibility changes.
     * A translated/collapsed platform view may be reported INVISIBLE before
     * the first authoritative PLAYING observation arrives, so gating this on
     * [mediaPlaying] would let Android pause a valid pending playback.
     * Visibility is presentation state; explicit JS commands own playback. */
    override fun onWindowVisibilityChanged(visibility: Int) {
        if (retainMediaLifecycle) {
            super.onWindowVisibilityChanged(View.VISIBLE)
        } else {
            super.onWindowVisibilityChanged(visibility)
        }
    }

    /** Flutter's platform-view compositor can also report the translated
     * surface as not visibility-aggregated even though this playback session
     * is intentionally still mounted. Keep that signal aligned with the
     * session lifetime for the same reason as window visibility above. */
    override fun onVisibilityAggregated(isVisible: Boolean) {
        super.onVisibilityAggregated(retainMediaLifecycle || isVisible)
    }

    /** Do not pause the session merely because Flutter/Android hides the view.
     * Explicit user/focus PAUSE still pauses the real HTML media element. */
    override fun onPause() {
        if (retainMediaLifecycle) return
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        // Explicit user pause is authoritative; resume only via Play.
    }

    fun disposeMedia() {
        retainMediaLifecycle = false
        loadGeneration++
        stopReconcilePolling()
        stopPlaybackForegroundService()
        try {
            evaluateJavascript("window.__vshotsDispose && window.__vshotsDispose();", null)
        } catch (_: Throwable) {
            // Best effort page-side timer cleanup.
        }
        if (VShotsBrowserPlaybackService.eventChannel === events) {
            VShotsBrowserPlaybackService.eventChannel = null
        }
        playbackState = BrowserPlaybackState.IDLE
        mediaPlaying = false
        adMuted = false
        stopLoading()
        loadUrl("about:blank")
    }
}

private class VShotsBrowserPlatformView(
    context: Context,
    id: Int,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) : PlatformView {
    private val channel = MethodChannel(messenger, "vshots/browser/$id")
    private val webView = VShotsBackgroundMediaWebView(context, channel)

    init {
        channel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "load" -> {
                    val args = call.arguments as? Map<*, *>
                    val url = args?.get("url")?.toString()
                        ?: (call.arguments as? String)
                        ?: ""
                    val generation = (args?.get("generation") as? Number)?.toLong()
                    val autoplay = args?.get("autoplay") as? Boolean ?: true
                    webView.load(url, generation, autoplay)
                    result.success(null)
                }
                "pause" -> {
                    webView.pauseMedia(
                        origin = "user",
                        requestedGeneration = requestedGeneration(call.arguments),
                        userInitiated = true,
                    )
                    result.success(null)
                }
                "focusPause" -> {
                    webView.pauseMedia(
                        origin = "focus",
                        requestedGeneration = requestedGeneration(call.arguments),
                        userInitiated = false,
                    )
                    result.success(null)
                }
                "play" -> {
                    webView.userPlay(requestedGeneration(call.arguments))
                    result.success(null)
                }
                "setContentBlocker" -> {
                    try {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        val enabled = (args["enabled"] as? Boolean) ?: true
                        val blocked = (args["blocked"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                        val essential = (args["essential"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                        val patterns = (args["patterns"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                        webView.setContentBlocker(enabled, blocked, essential, patterns)
                        result.success(null)
                    } catch (t: Throwable) {
                        // A blocker-config error must never take the browser down.
                        result.success(null)
                    }
                }
                "setAdAssist" -> {
                    webView.setAdAssist((call.arguments as? Boolean) ?: true)
                    result.success(null)
                }
                "updateNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    val title = args?.get("title")?.toString() ?: "V Shots"
                    val artist = args?.get("artist")?.toString() ?: "Music playback"
                    val artwork = args?.get("artwork")?.toString() ?: ""
                    val playing = args?.get("playing") as? Boolean ?: false
                    webView.updateNotification(title, artist, artwork, playing)
                    result.success(null)
                }
                "seekBy" -> {
                    // Seek the REAL media element (±seconds) without
                    // recreating the WebView. Used by the notification's
                    // rewind / fast-forward buttons and the media session.
                    val args = call.arguments as? Map<*, *>
                    val seconds = (args?.get("seconds") as? Number)?.toInt()
                        ?: (call.arguments as? Number)?.toInt()
                        ?: 10
                    val generation = requestedGeneration(call.arguments)
                    if (generation == null || generation == webView.currentGeneration()) {
                        webView.seekBy(seconds, generation)
                    }
                    result.success(null)
                }
                "seekTo" -> {
                    val args = call.arguments as? Map<*, *>
                    val positionMs = (args?.get("positionMs") as? Number)?.toLong() ?: 0L
                    val generation = requestedGeneration(call.arguments)
                    if (generation == null || generation == webView.currentGeneration()) {
                        webView.seekTo(positionMs, generation)
                    }
                    result.success(null)
                }
                "setVolume" -> {
                    // Audio-focus ducking: 0..1 on the real media element.
                    val args = call.arguments as? Map<*, *>
                    val raw = (args?.get("volume") as? Number)?.toDouble()
                        ?: (call.arguments as? Number)?.toDouble()
                        ?: 1.0
                    val volume = Math.max(0.0, Math.min(1.0, raw))
                    val generation = requestedGeneration(call.arguments)
                    if (generation == null || generation == webView.currentGeneration()) {
                        webView.setVolume(volume, generation)
                    }
                    result.success(null)
                }
                "dispose" -> {
                    webView.disposeMedia()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getView(): View = webView

    override fun dispose() {
        webView.disposeMedia()
        channel.setMethodCallHandler(null)
        webView.destroy()
    }
}

class VShotsBrowserPlatformViewFactory(
    private val messenger: io.flutter.plugin.common.BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return VShotsBrowserPlatformView(context, viewId, messenger)
    }
}

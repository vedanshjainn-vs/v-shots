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
import android.view.MotionEvent
import android.view.InputDevice
import android.os.SystemClock
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import java.io.ByteArrayInputStream
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.Locale

private const val VIEW_TYPE = "vshots/native_browser"
private const val TAG = "VShotsPlayback"

/**
 * App-wide YouTube playback assist (owner spec, Phase 17.10):
 *
 *  • COMPLETION OBSERVATION — the real media element reports a validated
 *    near-end/end event. The Flutter queue owner decides whether to advance;
 *    this WebView never starts another track from its polling callback.
 *
 *  • AD ASSIST — while the OFFICIAL YouTube player runs an in-stream ad:
 *      - the ad is muted (only the player's own video element state);
 *      - YouTube's own "Skip" button is clicked when it appears (the exact
 *        action a user would take; unskippable ads play muted in full);
 *      - nothing is blocked, hidden, resized or sped up; no ad-network
 *        interception, no unofficial APIs, no stream access.
 *    Ad completion restores the exact pre-ad content audio state; an
 *    explicit/system Play command still owns any playback transition.
 *
 * Only official, user-equivalent player controls are used. The assist is
 * gated by the remote flag `enable_youtube_ad_assist` (default ON) and is
 * YouTube-page-only — JioSaavn pages are never touched.
 */

/**
 * One-per-second playback poll. Returns:
 *   'ad'      — an in-stream ad is playing (player's own ad UI markers)
 *   'ended'   — media reached its natural end
 *   'nearend' — <=1.5 s left AND still playing (never while paused)
 *   'paused' / 'playing' / 'buffering' / 'none' / 'unknown'
 */
private const val YT_POLL_JS = """
(function(){
  try{
    function snapshot(state, v){
      var muted = v ? (v.muted ? '1' : '0') : '-1';
      var volume = v && isFinite(v.volume) ? String(v.volume) : '-1';
      return state + '|' + muted + '|' + volume;
    }
    var adOn = !!document.querySelector('.ad-showing');
    if(!adOn){
      // The overlay container remains mounted on ordinary YouTube content.
      // Require a visible ad-specific control/label before classifying this
      // media element as an official in-stream advertisement.
      var adEvidence = document.querySelector(
        '.ytp-ad-skip-button, .ytp-skip-ad-button,' +
        ' .ytp-ad-preview-container, .ytp-ad-text,' +
        ' .ytp-ad-duration-remaining'
      );
      if(adEvidence){
        var style = window.getComputedStyle(adEvidence);
        var rect = adEvidence.getBoundingClientRect();
        if(style.display !== 'none' && style.visibility !== 'hidden' &&
           style.opacity !== '0' && rect.width > 0 && rect.height > 0){
          adOn = true;
        }
      }
    }
    var v = document.querySelector('video,audio');
    if(!v){ return snapshot(adOn ? 'ad' : 'none', null); }
    if(adOn){ return snapshot('ad', v); }
    if(v.ended){ return snapshot('ended', v); }
    if(v.seeking || (!v.paused && v.readyState < 3)){ return snapshot('buffering', v); }
    var d = v.duration;
    if(d && isFinite(d) && !v.paused && v.currentTime >= d - 1.5){
      return snapshot('nearend', v);
    }
    return snapshot(v.paused ? 'paused' : 'playing', v);
  }catch(e){ return 'unknown|-1|-1'; }
})()
"""

/**
 * Position probe (every few poll ticks while playing): returns
 * "<positionMs>|<durationMs>" from the REAL media element so the media
 * session can render an accurate lock-screen/notification progress bar.
 * Returns "none" when no media element exists.
 */
private const val YT_POSITION_JS = """
(function(){
  try{
    var v=document.querySelector('video,audio');
    if(!v){ return 'none'; }
    var d=(v.duration&&isFinite(v.duration))?Math.round(v.duration*1000):-1;
    return Math.round(v.currentTime*1000)+'|'+d;
  }catch(e){ return 'none'; }
})()
"""

/**
 * Ad assist pass (runs each poll tick while an ad is active): mute the ad
 * audio, and click YouTube's OWN visible Skip button when it is shown.
 * Returns 'skipped' when a skip was clicked, 'muted' when only muted,
 * and captures the prior content audio state exactly once per ad.
 */
private const val YT_AD_ASSIST_JS = """
(function(){
  try{
    var skipped = false;
    var v = document.querySelector('video');
    if(!v){ return 'none'; }

    // Capture the CONTENT audio state exactly once per ad. This is separate
    // from the ad mute itself, so a muted ad can never become a permanently
    // muted song. The snapshot is page-local and is removed on restoration.
    if(!window.__vshotsAdAudioSnapshot){
      var previousVolume = (typeof v.volume === 'number' && isFinite(v.volume))
        ? v.volume : 1;
      window.__vshotsAdAudioSnapshot = {
        muted: !!v.muted,
        volume: previousVolume
      };
    }
    v.muted = true;
    v.volume = 0;

    var sels = ['button.ytp-ad-skip-button','button.ytp-skip-ad-button',
                '.ytp-ad-skip-button-modern button','button.ytp-ad-skip-button-modern'];
    for(var i=0;i<sels.length;i++){
      var b = document.querySelector(sels[i]);
      if(b && b.offsetParent !== null && !b.disabled){
        try{ b.click(); skipped = true; }catch(e){}
        break;
      }
    }
    return skipped ? 'skipped' : 'muted';
  }catch(e){ return 'err'; }
})()
"""

/** Restore the exact pre-ad content audio state; never hardcode volume. */
private const val YT_RESTORE_AD_AUDIO_JS = """
(function(){
  try{
    var v = document.querySelector('video,audio');
    var snapshot = window.__vshotsAdAudioSnapshot;
    if(!v || !snapshot){ return 'none'; }
    v.muted = !!snapshot.muted;
    if(typeof snapshot.volume === 'number' && isFinite(snapshot.volume)){
      v.volume = snapshot.volume;
    }
    var result = 'restored|' + (v.muted ? '1' : '0') + '|' + String(v.volume);
    try{ delete window.__vshotsAdAudioSnapshot; }catch(e){
      window.__vshotsAdAudioSnapshot = null;
    }
    return result;
  }catch(e){ return 'err'; }
})()
"""

/**
 * One-shot content initialization. It is called only for a valid CONTENT
 * generation after the ad state has been ruled out. It never calls play().
 */
private const val YT_VALIDATE_CONTENT_AUDIO_JS = """
(function(){
  try{
    var adOn = !!document.querySelector('.ad-showing');
    if(!adOn){
      // The overlay container remains mounted on ordinary YouTube content.
      // Require a visible ad-specific control/label before classifying this
      // media element as an official in-stream advertisement.
      var adEvidence = document.querySelector(
        '.ytp-ad-skip-button, .ytp-skip-ad-button,' +
        ' .ytp-ad-preview-container, .ytp-ad-text,' +
        ' .ytp-ad-duration-remaining'
      );
      if(adEvidence){
        var style = window.getComputedStyle(adEvidence);
        var rect = adEvidence.getBoundingClientRect();
        if(style.display !== 'none' && style.visibility !== 'hidden' &&
           style.opacity !== '0' && rect.width > 0 && rect.height > 0){
          adOn = true;
        }
      }
    }
    if(adOn){ return 'ad'; }
    var v = document.querySelector('video,audio');
    if(!v){ return 'none'; }
    if(window.__vshotsAdAudioSnapshot){ return 'ad-pending'; }

    // Fresh user-selected content is allowed one audio initialization. This
    // repairs WebView/YouTube muted autoplay without becoming a polling loop.
    // YouTube keeps its own player-volume state in addition to the HTML media
    // element. If its official visible Unmute control is present, invoke that
    // explicit control once before synchronizing the element properties.
    var unmute = document.querySelector('.ytp-unmute');
    if(unmute){
      var unmuteStyle = window.getComputedStyle(unmute);
      var unmuteRect = unmute.getBoundingClientRect();
      if(unmuteStyle.display !== 'none' && unmuteStyle.visibility !== 'hidden' &&
         unmuteStyle.opacity !== '0' && unmuteRect.width > 0 && unmuteRect.height > 0){
        var viewportWidth = Math.max(1, window.innerWidth || document.documentElement.clientWidth);
        var viewportHeight = Math.max(1, window.innerHeight || document.documentElement.clientHeight);
        var targetX = (unmuteRect.left + unmuteRect.width / 2) / viewportWidth;
        var targetY = (unmuteRect.top + unmuteRect.height / 2) / viewportHeight;
        return 'unmute-target|' + String(targetX) + '|' + String(targetY);
      }
    }
    v.muted = false;
    v.volume = 1.0;
    return 'validated|' + (v.muted ? '1' : '0') + '|' + String(v.volume);
  }catch(e){ return 'err'; }
})()
"""

/**
 * Discovery-only native browser view with FORCEFUL ad blocking.
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
/** Explicit audio state: content audio and muted ads are never one boolean. */
private enum class BrowserAudioState {
    PLAYING_WITH_AUDIO,
    PLAYING_MUTED_AD,
    PLAYING_MUTED_CONTENT,
    PAUSED,
    BUFFERING,
    ENDED,
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

private class VShotsBackgroundMediaWebView(
    context: Context,
    private val events: MethodChannel,
) : WebView(context) {

    private val appContext = context.applicationContext
    private val handler = Handler(Looper.getMainLooper())

    /** Monotonic load generation. Every async JS callback captures it so a
     * stale page cannot mutate the next track's state. */
    private var loadGeneration = 0L
    private var currentLoadUrl = ""
    private var playbackState = "idle"
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

    /**
     * Real touches on the embedded media surface are intentionally consumed by
     * the V Shots shell. This prevents an arbitrary video tap from becoming a
     * YouTube play/pause gesture. The only touch allowed through this WebView
     * is the generation-checked native touch delivered to YouTube's exact
     * unmute target by the already-validated audio path.
     */
    private var trustedTouchInFlight = false

    // ── FORCEFUL Ad Blocker State ──────────────────────────────────────────
    // ALWAYS ON by default. Populated from Dart via "setContentBlocker".
    // Host-exact + suffix matching + URL pattern matching.
    // Essential/allow hosts always pass (media must never be blocked).
    private var blockerEnabled = true
    private val blockedHosts = mutableSetOf<String>()
    private val essentialHosts = mutableSetOf<String>()
    private val adUrlPatterns = mutableListOf<String>()

    // Popup blocking state
    private var popupBlockedCount = 0

    private val playbackPoll = object : Runnable {
        private var tick = 0

        fun reset() {
            tick = 0
        }

        override fun run() {
            if (!isAttachedToWindow && !mediaPlaying) return
            val generation = loadGeneration
            evaluateJavascript(YT_POLL_JS) { result ->
                if (generation == loadGeneration) {
                    handlePollResult(cleanJsResult(result), generation)
                }
            }
            // Every ~5s while playing: report real position/duration. Position
            // is read-only and does not request focus or change play state.
            if (mediaPlaying && tick % 5 == 0) {
                evaluateJavascript(YT_POSITION_JS) { result ->
                    if (generation == loadGeneration) {
                        handlePositionResult(cleanJsResult(result), generation)
                    }
                }
            }
            tick++
            handler.postDelayed(this, 1000L)
        }
    }

    private fun handlePositionResult(result: String, generation: Long) {
        if (generation != loadGeneration || result == "none" || !result.contains("|")) return
        val parts = result.split("|")
        val positionMs = parts[0].toLongOrNull() ?: return
        val durationMs = parts.getOrNull(1)?.toLongOrNull() ?: -1L
        if (positionMs >= 0) {
            VShotsBrowserPlaybackService.updatePositionFromBrowser(
                positionMs = positionMs,
                durationMs = durationMs,
                generation = generation,
            )
            events.invokeMethod(
                "position",
                mapOf(
                    "positionMs" to positionMs,
                    "durationMs" to durationMs,
                    "generation" to generation,
                ),
            )
        }
    }

    /** True once the CURRENT load's media has reached its natural end.
     *  Reset on every new load so each video reports end exactly once. */
    private var endedReported = false

    /** True once the CURRENT load's media entered its last 1.5 s — the
     *  app-wide auto-advance trigger (owner spec: next track starts just
     *  BEFORE the song fully ends). Reset on every new load. */
    private var nearEndReported = false

    /** True while the YouTube page is playing an in-stream ad. */
    private var adActive = false

    /** Explicit audio state. A muted advertisement is never represented as a
     * muted content boolean, so content restoration has a single owner. */
    private var audioState = BrowserAudioState.PAUSED
    private var contentAudioValidationRequested = false
    private var contentAudioValidated = false
    private var adAudioAssistTouched = false
    private var adAssistInFlight = false
    private var adAudioRestoreInFlight = false

    /** Explicit user pause guard. Polling must never fight the user. */
    private var userPaused = false
    private var unexpectedPauseSinceMs = 0L
    private var pauseRecoveryAttempts = 0
    private var pauseRecoveryInFlight = false
    private val maxPauseRecoveryAttempts = 3

    /** Master switch for the ad assist (mute + official-skip click).
     *  Pushed from Dart (`enable_youtube_ad_assist` remote flag). */
    private var adAssistEnabled = true

    var mediaPlaying: Boolean = false
        private set

    private data class PollSnapshot(
        val state: String,
        val muted: Boolean?,
        val volume: Double?,
    )

    private fun parsePollSnapshot(result: String): PollSnapshot {
        val parts = result.split('|')
        val muted = when (parts.getOrNull(1)) {
            "1" -> true
            "0" -> false
            else -> null
        }
        val volume = parts.getOrNull(2)?.toDoubleOrNull()?.takeIf { it >= 0.0 }
        return PollSnapshot(
            state = parts.firstOrNull().orEmpty(),
            muted = muted,
            volume = volume,
        )
    }

    private fun setAudioState(next: BrowserAudioState) {
        if (audioState == next) return
        Log.d(TAG, "audio state: $audioState -> $next")
        audioState = next
        val playing = when (next) {
            BrowserAudioState.PLAYING_WITH_AUDIO,
            BrowserAudioState.PLAYING_MUTED_AD,
            BrowserAudioState.PLAYING_MUTED_CONTENT,
            -> true
            else -> false
        }
        events.invokeMethod(
            "audioState",
            mapOf(
                "state" to next.name.lowercase(Locale.US),
                "playing" to playing,
                "generation" to loadGeneration,
            ),
        )
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

    /**
     * YouTube can expose a real "Tap to unmute" overlay even when the HTML
     * media element is already playing. A JavaScript .click() is not a trusted
     * browser gesture, so it can be ignored by Chromium/YouTube. When the
     * official unmute target is visibly present, deliver one native touch to
     * that exact target. This is equivalent to the user's tap and avoids
     * tapping the video body (which would pause it).
     */
    private fun performTrustedUnmuteTap(x: Float, y: Float) {
        val now = SystemClock.uptimeMillis()
        val down = MotionEvent.obtain(now, now, MotionEvent.ACTION_DOWN, x, y, 0).apply {
            source = InputDevice.SOURCE_TOUCHSCREEN
        }
        val up = MotionEvent.obtain(now, now + 16L, MotionEvent.ACTION_UP, x, y, 0).apply {
            source = InputDevice.SOURCE_TOUCHSCREEN
        }
        trustedTouchInFlight = true
        try {
            dispatchTouchEvent(down)
            dispatchTouchEvent(up)
        } finally {
            trustedTouchInFlight = false
            down.recycle()
            up.recycle()
        }
    }

    /**
     * The embedded YouTube surface is video-only. Transport is owned by the V
     * Shots controls, so a generic touch cannot pause or resume the media.
     * Intercept at dispatch level so Chromium's internal child views cannot
     * receive an ordinary tap. Trusted unmute input temporarily passes through
     * the flag above.
     */
    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (!trustedTouchInFlight) return true
        return super.dispatchTouchEvent(event)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (trustedTouchInFlight) return super.onTouchEvent(event)
        return true
    }

    private fun updateContentAudioState(snapshot: PollSnapshot) {
        val audible = snapshot.muted == false && (snapshot.volume == null || snapshot.volume > 0.0)
        setAudioState(
            if (audible) BrowserAudioState.PLAYING_WITH_AUDIO
            else BrowserAudioState.PLAYING_MUTED_CONTENT,
        )
    }

    private fun recoverUnexpectedPause(generation: Long) {
        if (generation != loadGeneration || userPaused || adActive || pauseRecoveryInFlight) return
        if (pauseRecoveryAttempts >= maxPauseRecoveryAttempts) return
        val now = android.os.SystemClock.elapsedRealtime()
        if (unexpectedPauseSinceMs == 0L) unexpectedPauseSinceMs = now
        if (now - unexpectedPauseSinceMs < 300L) return
        pauseRecoveryAttempts += 1
        pauseRecoveryInFlight = true
        Log.d(TAG, "recovering unexpected pause attempt=$pauseRecoveryAttempts")
        VShotsBrowserPlaybackService.prepareForPlayback()
        setNativeWebViewAudioMuted(false)
        evaluateJavascript(
            generationGuardedJs(
                """(function(){try{var v=document.querySelector('video,audio');if(!v||v.ended)return 'none';v.muted=false;if(!v.volume||v.volume<=0)v.volume=1;var p=v.play();if(p&&p.catch)p.catch(function(){});return 'recovery-requested';}catch(e){return 'err';}})()""",
                generation,
            ),
        ) { result ->
            if (generation == loadGeneration) pauseRecoveryInFlight = false
        }
    }

    private fun handlePollResult(result: String, generation: Long) {
        if (generation != loadGeneration) return
        val snapshot = parsePollSnapshot(result)
        val currentUrl = url ?: ""
        val lower = currentUrl.lowercase(Locale.US)
        val isYouTube = lower.contains("youtube.com") || lower.contains("youtu.be")

        when (snapshot.state) {
            "ad" -> {
                setAdActive(true)
                setAudioState(BrowserAudioState.PLAYING_MUTED_AD)
                // An ad is a page state, not a new playback command. Keep the
                // active-media bit for the notification action, but never call
                // play or request focus from this poll callback.
                setPlaybackState("ad", mediaPlaying)
                if (adAssistEnabled) runAdAssist(generation)
            }
            else -> {
                if (adActive) {
                    setAdActive(false)
                    restoreAdAudioOrValidate(generation)
                }
                when (snapshot.state) {
                    "nearend" -> {
                        // Completion is emitted once, only while the real
                        // element is playing. The manager decides whether to
                        // advance; this layer never starts the next track.
                        if (isYouTube && !nearEndReported) {
                            nearEndReported = true
                            Log.d(TAG, "near-end completion reported")
                            events.invokeMethod("videoEnded", mapOf("generation" to generation))
                        }
                        if (!userPaused) {
                            updateContentAudioState(snapshot)
                            ensureContentAudio(generation)
                            setPlaybackState("playing", true)
                        } else {
                            setAudioState(BrowserAudioState.PAUSED)
                            setPlaybackState("paused", false)
                        }
                    }
                    "ended" -> {
                        if (isYouTube && !endedReported) {
                            endedReported = true
                            Log.d(TAG, "video.ended reported")
                            events.invokeMethod("videoEnded", mapOf("generation" to generation))
                        }
                        setAudioState(BrowserAudioState.ENDED)
                        setPlaybackState("ended", false)
                    }
                    "playing" -> {
                        unexpectedPauseSinceMs = 0L
                        pauseRecoveryInFlight = false
                        if (!userPaused) {
                            updateContentAudioState(snapshot)
                            ensureContentAudio(generation)
                            setPlaybackState("playing", true)
                        } else {
                            setAudioState(BrowserAudioState.PAUSED)
                            setPlaybackState("paused", false)
                        }
                    }
                    "buffering" -> {
                        setAudioState(BrowserAudioState.BUFFERING)
                        setPlaybackState("buffering", mediaPlaying)
                    }
                    "paused" -> {
                        if (userPaused) {
                            unexpectedPauseSinceMs = 0L
                            pauseRecoveryInFlight = false
                            setAudioState(BrowserAudioState.PAUSED)
                            setPlaybackState("paused", false)
                        } else {
                            if (unexpectedPauseSinceMs == 0L) {
                                unexpectedPauseSinceMs = android.os.SystemClock.elapsedRealtime()
                            }
                            recoverUnexpectedPause(generation)
                        }
                    }
                    else -> Unit // 'none' / 'unknown' — keep current state
                }
            }
        }
    }

    private fun setAdActive(value: Boolean) {
        if (adActive == value) return
        adActive = value
        Log.d(TAG, if (value) "in-stream ad started" else "in-stream ad ended")
        events.invokeMethod("adState", value)
    }

    /**
     * YouTube AD ASSIST (owner spec) — uses ONLY the controls the official
     * YouTube player itself exposes:
     *
     *   1. While an in-stream ad plays, the ad is muted (the app's music
     *      must not blast ad audio between songs).
     *   2. When YouTube shows its own "Skip" button, it is clicked — the
     *      same action a user performs. Unskippable ads are NEVER
     *      interfered with: they play (muted) in full.
     *   3. Nothing is blocked, hidden, resized or sped up. No ad-network
     *      interception, no unofficial APIs, no stream access.
     *
     * Gated by `enable_youtube_ad_assist` (remote flag, default ON).
     */
    /**
     * Executes a mutating JS command only in the page generation that issued
     * it. The marker is installed after the matching page finishes, so an old
     * callback cannot alter a newly selected track.
     */
    private fun generationGuardedJs(script: String, generation: Long): String {
        return """
            (function(){
              if(window.__vshotsNativeGeneration !== $generation){ return 'stale'; }
              return $script;
            })()
        """.trimIndent()
    }

    private fun runAdAssist(generation: Long) {
        if (generation != loadGeneration || adAssistInFlight) return
        adAssistInFlight = true
        evaluateJavascript(generationGuardedJs(YT_AD_ASSIST_JS, generation)) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            adAssistInFlight = false
            val clean = cleanJsResult(result)
            if (clean == "muted" || clean == "skipped") {
                adAudioAssistTouched = true
                // The ad may have ended while this JS command was in flight.
                // Finish restoration now rather than leaving content muted.
                if (!adActive) restoreAdAudioOrValidate(generation)
            }
            Log.d(TAG, "ad assist: $clean")
        }
    }

    /** Restore the exact content state captured by the ad assist. If the first
     * page state was a pre-roll, perform the one fresh-content validation only
     * after the ad snapshot has been removed. */
    private fun restoreAdAudioOrValidate(generation: Long) {
        if (generation != loadGeneration ||
            adAudioRestoreInFlight ||
            adAssistInFlight
        ) return
        if (!adAudioAssistTouched) {
            ensureContentAudio(generation)
            return
        }
        adAudioRestoreInFlight = true
        evaluateJavascript(generationGuardedJs(YT_RESTORE_AD_AUDIO_JS, generation)) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            adAudioRestoreInFlight = false
            adAudioAssistTouched = false
            val clean = cleanJsResult(result)
            if (clean.startsWith("restored|")) {
                val restored = parsePollSnapshot("playing|${clean.removePrefix("restored|")}")
                updateContentAudioState(restored)
            }
            if (!userPaused) ensureContentAudio(generation)
            Log.d(TAG, "ad audio restore: $clean")
        }
    }

    /** One explicit content-audio validation per valid generation. */
    private fun ensureContentAudio(generation: Long) {
        if (generation != loadGeneration ||
            userPaused ||
            adActive ||
            contentAudioValidated ||
            contentAudioValidationRequested
        ) return
        contentAudioValidationRequested = true
        evaluateJavascript(generationGuardedJs(YT_VALIDATE_CONTENT_AUDIO_JS, generation)) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            val clean = cleanJsResult(result)
            when {
                clean.startsWith("validated|") -> {
                    contentAudioValidated = true
                    val validated = parsePollSnapshot("playing|${clean.removePrefix("validated|")}")
                    updateContentAudioState(validated)
                    Log.d(TAG, "content audio validated: $clean")
                }
                clean.startsWith("unmute-target|") -> {
                    val parts = clean.split('|')
                    val nx = parts.getOrNull(1)?.toFloatOrNull()
                    val ny = parts.getOrNull(2)?.toFloatOrNull()
                    val x = nx?.let { it * width.toFloat() }
                    val y = ny?.let { it * height.toFloat() }
                    if (nx != null && ny != null && x != null && y != null &&
                        nx in 0f..1f && ny in 0f..1f &&
                        x >= 0f && y >= 0f && x <= width.toFloat() && y <= height.toFloat()) {
                        Log.d(TAG, "trusted YouTube unmute tap: normalized=$nx,$ny px=$x,$y")
                        performTrustedUnmuteTap(x, y)
                        handler.postDelayed({
                            if (generation != loadGeneration || userPaused || adActive) return@postDelayed
                            setNativeWebViewAudioMuted(false)
                            evaluateJavascript(
                                generationGuardedJs(
                                    """(function(){
                                      try{
                                        var v=document.querySelector('video,audio');
                                        if(!v){return 'none';}
                                        v.muted=false;
                                        if(!v.volume || v.volume <= 0) v.volume=1;
                                        return 'sync|' + (v.muted ? '1' : '0') + '|' + String(v.volume);
                                      }catch(e){return 'err';}
                                    })()""",
                                    generation,
                                ),
                            ) { syncResult ->
                                if (generation != loadGeneration) return@evaluateJavascript
                                val sync = cleanJsResult(syncResult)
                                if (sync.startsWith("sync|0|")) {
                                    contentAudioValidated = true
                                    updateContentAudioState(parsePollSnapshot("playing|${sync.removePrefix("sync|")}"))
                                }
                                contentAudioValidationRequested = false
                            }
                        }, 80L)
                    } else {
                        contentAudioValidationRequested = false
                    }
                }
                clean == "ad" || clean == "ad-pending" -> {
                    contentAudioValidationRequested = false
                }
                else -> {
                    contentAudioValidationRequested = false
                    Log.d(TAG, "content audio validation: $clean")
                }
            }
        }
    }

    init {
        VShotsBrowserPlaybackService.eventChannel = events
        setBackgroundColor(Color.BLACK)
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.mediaPlaybackRequiresUserGesture = false
        // Clear any application-level WebView mute before the first page.
        setNativeWebViewAudioMuted(false)
        settings.loadsImagesAutomatically = true
        settings.javaScriptCanOpenWindowsAutomatically = false
        settings.setSupportMultipleWindows(false) // Block popup windows
        CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
        webChromeClient = object : WebChromeClient() {
            // Override to block popup windows completely
            override fun onCreateWindow(
                view: WebView?,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: android.os.Message?
            ): Boolean {
                // Block ALL popup windows
                popupBlockedCount++
                events.invokeMethod("blocked", "popup-window")
                return false
            }
        }

        webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                if (!isCurrentPage(url)) return
                events.invokeMethod("pageStarted", mapOf("generation" to loadGeneration))
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                if (!isCurrentPage(url)) return
                val generation = loadGeneration
                // Complete the page-generation handshake before Flutter is
                // allowed to issue the single autoplay command.
                evaluateJavascript(
                    "window.__vshotsNativeGeneration = $generation;",
                ) { _ ->
                    if (generation != loadGeneration) return@evaluateJavascript
                    events.invokeMethod("pageFinished", mapOf("generation" to generation))
                    startPlaybackPolling()
                }
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
             * NETWORK-LEVEL AD BLOCKING — Primary defense.
             * Intercepts ALL resource requests and blocks ads before they load.
             * Runs on BACKGROUND thread — never touch MethodChannel directly.
             *
             * IMPORTANT: YouTube ad blocking works by checking URL patterns
             * even on essential hosts (youtube.com, googlevideo.com, etc.)
             * because YouTube serves ads from the same domains as content.
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
             *
             * Includes YouTube-specific ad redirect blocking.
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
                    // Block suspicious schemes
                    reportBlock("suspicious-scheme:$scheme")
                    return true
                }

                return false
            }
        }
    }

    /**
     * Cosmetic ad blocking — hides residual ad containers via CSS.
     * Runs once per page load. Never touches video/audio/nav/content elements.
     * This is a SECONDARY defense after network-level blocking.
     *
     * Includes YOUTUBE-SPECIFIC ad selectors for YouTube pages.
     */
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
            lowerQuery.contains("vpaid")) {
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
        // Report to Dart on MAIN thread (stats only)
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
        endedReported = false
        nearEndReported = false
        adActive = false
        setAudioState(if (autoplay) BrowserAudioState.BUFFERING else BrowserAudioState.PAUSED)
        contentAudioValidationRequested = false
        contentAudioValidated = false
        adAudioAssistTouched = false
        adAssistInFlight = false
        adAudioRestoreInFlight = false
        userPaused = !autoplay
        unexpectedPauseSinceMs = 0L
        pauseRecoveryAttempts = 0
        pauseRecoveryInFlight = false
        mediaPlaying = false
        setNativeWebViewAudioMuted(false)
        setPlaybackState("loading", false)
        playbackPoll.reset()
        // Cancel the previous document before starting a new generation. This
        // prevents late callbacks from the old navigation from becoming the
        // new track's page-finished/autoplay signal.
        stopLoading()

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

    private fun setPlaybackState(state: String, playing: Boolean) {
        val changed = playbackState != state || mediaPlaying != playing
        playbackState = state
        mediaPlaying = playing
        if (!changed) return
        startPlaybackForegroundService(playing = playing, state = state)
        events.invokeMethod(
            "playbackState",
            mapOf(
                "playing" to playing,
                "state" to state,
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
            state = playbackState,
        )
    }

    private fun startPlaybackPolling() {
        handler.removeCallbacks(playbackPoll)
        handler.post(playbackPoll)
    }

    private fun stopPlaybackPolling() {
        handler.removeCallbacks(playbackPoll)
    }

    private fun startPlaybackForegroundService(
        title: String? = null,
        artist: String? = null,
        artwork: String? = null,
        playing: Boolean = mediaPlaying,
        positionMs: Long = -1L,
        durationMs: Long = -1L,
        state: String = playbackState,
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

    fun seekBy(seconds: Int, requestedGeneration: Long? = null) {
        val generation = requestedGeneration ?: loadGeneration
        if (generation != loadGeneration) return
        evaluateJavascript(
            generationGuardedJs(
                """(function(){
                  try{
                    var v=document.querySelector('video,audio');
                    if(!v){return 'none';}
                    var d=(v.duration&&isFinite(v.duration))?v.duration:null;
                    var t=v.currentTime+($seconds);
                    if(d!=null){t=Math.max(0,Math.min(d,t));}
                    else{t=Math.max(0,t);}
                    v.currentTime=t;
                    return 'ok';
                  }catch(e){return 'err';}
                })()""",
                generation,
            ),
        ) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            // Seeking is a read/write transport command, not a playback state
            // transition. The next read-only poll remains authoritative.
            Log.d(TAG, "seek: ${cleanJsResult(result)}")
        }
    }

    fun seekTo(positionMs: Long, requestedGeneration: Long? = null) {
        val generation = requestedGeneration ?: loadGeneration
        if (generation != loadGeneration || positionMs < 0L) return
        evaluateJavascript(
            generationGuardedJs(
                """(function(){
                  try{
                    var v=document.querySelector('video,audio');
                    if(!v){return 'none';}
                    var target=$positionMs/1000;
                    if(v.duration && isFinite(v.duration)){
                      target=Math.max(0,Math.min(v.duration,target));
                    }else{
                      target=Math.max(0,target);
                    }
                    v.currentTime=target;
                    return 'ok|' + String(Math.round(target*1000));
                  }catch(e){return 'err';}
                })()""",
                generation,
            ),
        ) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            Log.d(TAG, "seekTo: ${cleanJsResult(result)}")
        }
    }

    fun setVolume(volume: Double, requestedGeneration: Long? = null) {
        val generation = requestedGeneration ?: loadGeneration
        if (generation != loadGeneration) return
        evaluateJavascript(
            generationGuardedJs(
                """(function(){
                  try{
                    var v=document.querySelector('video,audio');
                    if(!v){return 'none';}
                    v.muted=false;
                    v.volume=$volume;
                    return 'ok';
                  }catch(e){return 'err';}
                })()""",
                generation,
            ),
        ) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            Log.d(TAG, "volume: ${cleanJsResult(result)}")
        }
    }

    fun pauseMedia(userInitiated: Boolean = true, requestedGeneration: Long? = null) {
        val generation = requestedGeneration ?: loadGeneration
        if (generation != loadGeneration) return
        userPaused = true
        setAudioState(BrowserAudioState.PAUSED)
        evaluateJavascript(
            generationGuardedJs(
                """
                (function(){
                  var v=document.querySelector('video,audio');
                  if(!v){return 'none';}
                  if(!v.paused){ v.pause(); }
                  return 'paused';
                })()
                """.trimIndent(),
                generation,
            ),
        ) { _ ->
            if (generation != loadGeneration) return@evaluateJavascript
            setPlaybackState("paused", false)
        }
        setPlaybackState("paused", false)
        if (userInitiated) {
            startPlaybackForegroundService(
                playing = false,
                state = "paused",
                userCommand = "pause",
            )
        }
    }

    fun userPlay(requestedGeneration: Long? = null) {
        val generation = requestedGeneration ?: loadGeneration
        if (generation != loadGeneration) return
        userPaused = false
        // Acquire audio focus and clear native WebView mute BEFORE play.
        VShotsBrowserPlaybackService.prepareForPlayback()
        setNativeWebViewAudioMuted(false)
        startPlaybackForegroundService(
            playing = mediaPlaying,
            state = playbackState,
            userCommand = "play",
        )
        evaluateJavascript(
            generationGuardedJs(
                """
                (function(){
                  var adOn = !!document.querySelector('.ad-showing');
                  if(!adOn){
                    var adEvidence = document.querySelector(
                      '.ytp-ad-skip-button, .ytp-skip-ad-button,' +
                      ' .ytp-ad-preview-container, .ytp-ad-text,' +
                      ' .ytp-ad-duration-remaining'
                    );
                    if(adEvidence){
                      var style = window.getComputedStyle(adEvidence);
                      var rect = adEvidence.getBoundingClientRect();
                      if(style.display !== 'none' && style.visibility !== 'hidden' &&
                         style.opacity !== '0' && rect.width > 0 && rect.height > 0){
                        adOn = true;
                      }
                    }
                  }
                  if(adOn){ return 'ad'; }
                  var v=document.querySelector('video,audio');
                  if(!v){return 'none';}
                  v.muted=false; v.volume=1;
                  var p=v.play();
                  if(p && p.catch){p.catch(function(){});}
                  return 'requested';
                })()
                """.trimIndent(),
                generation,
            ),
        ) { result ->
            if (generation != loadGeneration) return@evaluateJavascript
            // "requested" only means HTMLMediaElement.play() was invoked.
            // Its Promise can still be rejected by WebView autoplay policy,
            // so observed CONTENT+PLAYING polling must perform the one audio
            // validation instead of treating this request as success.
            Log.d(TAG, "explicit play: ${cleanJsResult(result)}")
        }
    }

    private fun cleanJsResult(result: String?): String {
        return result.orEmpty().trim().trim('"').lowercase(Locale.US)
    }

    /** Keep the WebView media lifecycle alive across Android visibility changes.
     * A translated/collapsed platform view may be reported INVISIBLE before
     * the first authoritative PLAYING poll arrives, so gating this on
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
     * Explicit user/focus PAUSE still calls pauseMedia() and pauses the real
     * HTML media element. */
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
        stopPlaybackPolling()
        stopPlaybackForegroundService()
        if (VShotsBrowserPlaybackService.eventChannel === events) {
            VShotsBrowserPlaybackService.eventChannel = null
        }
        playbackState = "idle"
        mediaPlaying = false
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
                        userInitiated = true,
                        requestedGeneration = requestedGeneration(call.arguments),
                    )
                    result.success(null)
                }
                "focusPause" -> {
                    webView.pauseMedia(
                        userInitiated = false,
                        requestedGeneration = requestedGeneration(call.arguments),
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
                    // Volume 0 also unmutes so ducked playback is audible.
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

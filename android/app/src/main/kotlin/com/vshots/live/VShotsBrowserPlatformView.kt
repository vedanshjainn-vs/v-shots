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
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import java.io.ByteArrayInputStream
import android.webkit.WebView
import android.webkit.WebViewClient
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
 *  • EARLY AUTO-ADVANCE — the next queued track starts ~1.5 s BEFORE the
 *    current one finishes. Consistent across Home / Discover / playlists /
 *    the queue because every surface plays through this ONE WebView.
 *
 *  • AD ASSIST — while the OFFICIAL YouTube player runs an in-stream ad:
 *      - the ad is muted (only the player's own video element state);
 *      - YouTube's own "Skip" button is clicked when it appears (the exact
 *        action a user would take; unskippable ads play muted in full);
 *      - nothing is blocked, hidden, resized or sped up; no ad-network
 *        interception, no unofficial APIs, no stream access.
 *    When the ad ends the main track is unmuted and playback resumed
 *    automatically (bounded recovery window so a deliberate user pause is
 *    never overridden).
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
 *   'paused' / 'playing' / 'none' / 'unknown'
 */
private const val YT_POLL_JS = """
(function(){
  try{
    var adOn = !!document.querySelector('.ad-showing');
    if(!adOn){
      var ui = document.querySelector('.videoAdUi, .ytp-ad-player-overlay');
      if(ui && ui.offsetParent !== null){ adOn = true; }
    }
    var v = document.querySelector('video,audio');
    if(!v){ return adOn ? 'ad' : 'none'; }
    if(adOn){ return 'ad'; }
    if(v.ended){ return 'ended'; }
    var d = v.duration;
    if(d && isFinite(d) && !v.paused && v.currentTime >= d - 1.5){ return 'nearend'; }
    return v.paused ? 'paused' : 'playing';
  }catch(e){ return 'unknown'; }
})()
"""

/**
 * Ad assist pass (runs each poll tick while an ad is active): mute the ad
 * audio, and click YouTube's OWN visible Skip button when it is shown.
 * Returns 'skipped' when a skip was clicked, 'muted' when only muted,
 * 'ok' when nothing needed doing.
 */
private const val YT_AD_ASSIST_JS = """
(function(){
  try{
    var skipped = false;
    var v = document.querySelector('video');
    if(v && !v.muted){ v.muted = true; v.volume = 0; }
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

/**
 * Post-ad resume pass: unmute the main track, press play when paused, and
 * click YouTube's own mute/play controls only when they advertise the state
 * we need. The main music track is ALWAYS unmuted.
 */
private const val YT_RESUME_JS = """
(function(){
  try{
    var v = document.querySelector('video');
    if(v){
      v.muted = false; v.volume = 1;
      if(v.paused){
        var p = v.play();
        if(p && p.catch){ p.catch(function(){}); }
      }
    }
    var mb = document.querySelector('.ytp-mute-button');
    if(mb){
      var lab = ((mb.getAttribute('aria-label')||'') + ' ' + (mb.getAttribute('title')||'')).toLowerCase();
      if(lab.indexOf('unmute') >= 0){ try{ mb.click(); }catch(e){} }
    }
    var pb = document.querySelector('button.ytp-play-button');
    if(v && v.paused && pb && pb.offsetParent !== null){ try{ pb.click(); }catch(e){} }
    return 'ok';
  }catch(e){ return 'err'; }
})()
"""

/**
 * Discovery-only native browser view with FORCEFUL ad blocking.
 *
 * Third-party ad blocking for non-YouTube pages. YouTube watch-page
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
        override fun run() {
            if (!isAttachedToWindow && !mediaPlaying) return
            evaluateJavascript(YT_POLL_JS) { result ->
                handlePollResult(cleanJsResult(result))
            }
            handler.postDelayed(this, 1000L)
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

    /** ElapsedRealtime stamp of the most recent ad→content transition
     *  (window for stuck-after-ad recovery). */
    private var adJustEndedAt = 0L

    /** Master switch for the ad assist (mute + official-skip click +
     *  resume). Pushed from Dart (`enable_youtube_ad_assist` remote flag). */
    private var adAssistEnabled = true

    var mediaPlaying: Boolean = false
        private set

    private fun handlePollResult(state: String) {
        val currentUrl = url ?: ""
        val lower = currentUrl.lowercase(Locale.US)
        val isYouTube = lower.contains("youtube.com") || lower.contains("youtu.be")

        when (state) {
            "ad" -> {
                setAdActive(true)
                setMediaPlaying(true)
                if (adAssistEnabled) runAdAssist()
            }
            else -> {
                if (adActive) {
                    // Ad → content transition: unmute + resume the main
                    // track, and open the stuck-recovery window.
                    adJustEndedAt = android.os.SystemClock.elapsedRealtime()
                    setAdActive(false)
                    runResumeAfterAd()
                }
                when (state) {
                    "nearend" -> {
                        // Early auto-advance: YouTube pages ONLY, and the
                        // JS only reports near-end while actually playing
                        // (never while the user paused).
                        if (isYouTube && !nearEndReported) {
                            nearEndReported = true
                            Log.d(TAG, "near-end auto-advance fired")
                            events.invokeMethod("videoEnded", null)
                        }
                        setMediaPlaying(true)
                    }
                    "ended" -> {
                        // Real end (fallback for videos with unknown
                        // duration). Never fired while an in-stream ad is
                        // showing — the ad's own video-end is not a track
                        // end (it would wrongly skip the queue).
                        if (isYouTube && !adActive && !endedReported) {
                            endedReported = true
                            Log.d(TAG, "video.ended fired")
                            events.invokeMethod("videoEnded", null)
                        }
                        setMediaPlaying(false)
                    }
                    "playing" -> setMediaPlaying(true)
                    "paused" -> {
                        // Stuck-after-ad recovery: within a short window
                        // after an ad ends, resume the main content instead
                        // of leaving the player paused. Outside the window
                        // a pause is the USER's choice — never fight it.
                        val sinceAd = if (adJustEndedAt == 0L) Long.MAX_VALUE
                        else android.os.SystemClock.elapsedRealtime() - adJustEndedAt
                        if (sinceAd in 0..6000) {
                            runResumeAfterAd()
                        } else {
                            setMediaPlaying(false)
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
    private fun runAdAssist() {
        evaluateJavascript(YT_AD_ASSIST_JS) { result ->
            Log.d(TAG, "ad assist: ${cleanJsResult(result)}")
        }
    }

    /**
     * After an ad ends: unmute the main track, press play if the player is
     * paused (and click YouTube's own mute/play controls only when they
     * advertise the state we need). The main music track is ALWAYS unmuted.
     */
    private fun runResumeAfterAd() {
        evaluateJavascript(YT_RESUME_JS) { result ->
            Log.d(TAG, "post-ad resume: ${cleanJsResult(result)}")
        }
    }

    init {
        setBackgroundColor(Color.BLACK)
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.mediaPlaybackRequiresUserGesture = false
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
                events.invokeMethod("pageStarted", null)
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                events.invokeMethod("pageFinished", null)
                startPlaybackPolling()
                attemptAutoplayWithAudio()
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?,
            ) {
                if (request?.isForMainFrame != false) {
                    events.invokeMethod("error", "Playback failed — please retry")
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

                    // YouTube (and Google ad CDNs used by the YouTube watch page)
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

            /** Google ad CDNs used by the YouTube watch page — never blocked. */
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

    fun load(url: String) {
        if (!url.startsWith("https://")) return
        val host = Uri.parse(url).host?.lowercase(Locale.US) ?: return
        if (isDeniedJioHost(host)) return
        endedReported = false
        nearEndReported = false
        adActive = false
        adJustEndedAt = 0L
        loadUrl(url)
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

    fun reloadCurrent() {
        endedReported = false
        nearEndReported = false
        adActive = false
        adJustEndedAt = 0L
        reload()
    }

    fun setMediaPlaying(value: Boolean) {
        if (mediaPlaying == value) return
        mediaPlaying = value
        if (value) {
            startPlaybackForegroundService()
        } else {
            stopPlaybackForegroundService()
        }
        events.invokeMethod("playbackState", value)
    }

    private fun startPlaybackPolling() {
        handler.removeCallbacks(playbackPoll)
        handler.post(playbackPoll)
    }

    private fun stopPlaybackPolling() {
        handler.removeCallbacks(playbackPoll)
    }

    private fun startPlaybackForegroundService() {
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

    private fun stopPlaybackForegroundService() {
        try {
            appContext.stopService(
                Intent(appContext, VShotsBrowserPlaybackService::class.java),
            )
        } catch (_: Exception) {
            // Best effort only.
        }
    }

    fun pauseMedia() {
        evaluateJavascript(
            """
            (function(){
              var v=document.querySelector('video,audio');
              if(!v){return 'none';}
              if(!v.paused){ v.pause(); }
              return 'paused';
            })()
            """.trimIndent(),
        ) { result ->
            setMediaPlaying(false)
        }
    }

    fun togglePlayback() {
        evaluateJavascript(
            """
            (function(){
              var v=document.querySelector('video');
              if(!v){return 'none';}
              if(v.paused){
                v.muted=false; v.volume=1;
                var p=v.play();
                return p ? 'playing' : 'playing';
              }
              v.pause();
              return 'paused';
            })()
            """.trimIndent(),
        ) { result ->
            val state = cleanJsResult(result)
            setMediaPlaying(state.contains("playing"))
        }
    }

    /**
     * Best-effort autoplay + unmute pass. The WebView setting removes the
     * native gesture requirement; this JS pass additionally clicks YouTube's
     * own unmute controls when the mobile page exposes them.
     *
     * We never hide a muted player pretending it is audible: if YouTube still
     * blocks unmuted autoplay, the real YouTube control remains visible.
     */
    private fun attemptAutoplayWithAudio() {
        // YouTube pages ONLY: the pass exists to unmute/autoplay the official
        // YouTube player. It must never run on JioSaavn pages — clicking
        // random controls or forcing play there would start the wrong song.
        // (This class extends WebView, so the page URL is `url` — not an
        // outer `webView` reference.)
        val currentUrl = url ?: return
        val currentHost = currentUrl.lowercase(Locale.US)
        if (!currentHost.contains("youtube.com") &&
            !currentHost.contains("youtu.be")
        ) return
        evaluateJavascript(
            """
            (function(){
              try {
                var v=document.querySelector('video,audio');
                var buttons=document.querySelectorAll('button,[role="button"]');
                for(var i=0;i<buttons.length;i++){
                  var b=buttons[i];
                  var label=((b.getAttribute('aria-label')||'')+' '+(b.getAttribute('title')||'')).toLowerCase();
                  if(label.indexOf('unmute')>=0 || label.indexOf('tap to unmute')>=0){
                    try{ b.click(); }catch(e){}
                  }
                }
                if(v){
                  v.muted=false;
                  v.volume=1;
                  var p=v.play();
                  if(p && p.catch){p.catch(function(){});}
                  return (!v.paused ? 'playing' : 'blocked');
                }
              }catch(e){}
              return 'no-video';
            })()
            """.trimIndent(),
        ) { result ->
            if (cleanJsResult(result) == "playing") {
                setMediaPlaying(true)
            }
        }
    }

    private fun cleanJsResult(result: String?): String {
        return result.orEmpty().trim().trim('"').lowercase(Locale.US)
    }

    /** Keep active WebView media alive across Android visibility changes. */
    override fun onWindowVisibilityChanged(visibility: Int) {
        if (mediaPlaying) {
            super.onWindowVisibilityChanged(View.VISIBLE)
        } else {
            super.onWindowVisibilityChanged(visibility)
        }
    }

    /** Do not pause active Discovery media just because the Activity is hidden. */
    override fun onPause() {
        if (mediaPlaying) return
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (mediaPlaying) attemptAutoplayWithAudio()
    }

    fun disposeMedia() {
        stopPlaybackPolling()
        setMediaPlaying(false)
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
                    webView.load(call.arguments as? String ?: "")
                    result.success(null)
                }
                "reload" -> {
                    webView.reloadCurrent()
                    result.success(null)
                }
                "toggle" -> {
                    webView.togglePlayback()
                    result.success(null)
                }
                "pause" -> {
                    webView.pauseMedia()
                    result.success(null)
                }
                "play" -> {
                    webView.evaluateJavascript(
                        "(function(){var v=document.querySelector('video,audio');if(!v){return 'none';}v.muted=false;v.volume=1;var p=v.play();return 'playing';})()",
                    ) { value ->
                        webView.setMediaPlaying(clean(value) == "playing")
                    }
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
                "dispose" -> {
                    webView.disposeMedia()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun clean(value: String?): String = value.orEmpty().trim().trim('"').lowercase(Locale.US)

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

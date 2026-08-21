package com.vshots.live

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
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
            evaluateJavascript(
                "(function(){var v=document.querySelector('video');if(!v){return 'none';}if(v.ended){return 'ended';}return v.paused?'paused':'playing';})()",
            ) { result ->
                val state = cleanJsResult(result)
                setMediaPlaying(state == "playing")
                if (state == "ended" && !endedReported) {
                    endedReported = true
                    events.invokeMethod("videoEnded", null)
                }
            }
            handler.postDelayed(this, 1000L)
        }
    }

    /** True once the CURRENT load's media has reached its natural end.
     *  Reset on every new load so each video reports end exactly once. */
    private var endedReported = false

    var mediaPlaying: Boolean = false
        private set

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
                applyCosmeticBlocking()
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
    private fun applyCosmeticBlocking() {
        if (!blockerEnabled) return
        evaluateJavascript(
            "(function(){try{" +
            "var s=document.createElement('style');" +
            "s.setAttribute('id','vshots-adblock');" +
            "s.textContent='" +
            // Google AdSense/DFP
            "[data-google-query-id]," +
            "ins.adsbygoogle," +
            "div[id^=google_ads_]," +
            "iframe[src*=doubleclick]," +
            "iframe[src*=googlesyndication]," +
            "iframe[src*=googleadservices]," +
            "div[class*=ad-slot]," +
            "div[class*=adslot]," +
            "div[class*=ad-container]," +
            "div[id*=ad-container]," +
            "aside[class*=advert]," +
            "div[data-ad]," +
            "div[data-ad-client]," +
            "div[id^=div-gpt-ad]," +
            // Common ad containers
            "div[class*=adsbygoogle]," +
            "div[class*=ad-banner]," +
            "div[class*=ad-wrapper]," +
            "div[class*=ad-unit]," +
            "div[class*=ad-space]," +
            "div[class*=ad-placement]," +
            "div[class*=ad-zone]," +
            "div[class*=ad-region]," +
            "div[class*=ad-area]," +
            "div[class*=ad-block]," +
            "div[class*=ad-panel]," +
            "div[class*=ad-box]," +
            "div[class*=ad-card]," +
            "div[class*=ad-tile]," +
            "div[class*=ad-row]," +
            "div[class*=ad-column]," +
            "div[class*=ad-grid]," +
            "div[class*=ad-list]," +
            "div[class*=ad-feed]," +
            "div[class*=ad-stream]," +
            "div[class*=ad-carousel]," +
            "div[class*=ad-slider]," +
            "div[class*=ad-popup]," +
            "div[class*=ad-modal]," +
            "div[class*=ad-overlay]," +
            "div[class*=ad-interstitial]," +
            "div[class*=ad-fullscreen]," +
            "div[class*=ad-sticky]," +
            "div[class*=ad-fixed]," +
            "div[class*=ad-floating]," +
            "div[class*=ad-bottom]," +
            "div[class*=ad-top]," +
            "div[class*=ad-left]," +
            "div[class*=ad-right]," +
            "div[class*=ad-header]," +
            "div[class*=ad-footer]," +
            "div[class*=ad-sidebar]," +
            // Video ad overlays
            "div[class*=video-ad]," +
            "div[class*=preroll]," +
            "div[class*=midroll]," +
            "div[class*=postroll]," +
            "div[class*=ad-break]," +
            "div[class*=ad-pod]," +
            "div[class*=ad-slate]," +
            "div[class*=ad-companion]," +
            // Ad iframes
            "iframe[class*=ad]," +
            "iframe[id*=ad]," +
            "iframe[name*=ad]," +
            "iframe[data-ad]," +
            "iframe[src*=ad]," +
            "iframe[src*=ads]," +
            "iframe[src*=banner]," +
            "iframe[src*=sponsor]," +
            "iframe[src*=promo]," +
            // Popup/overlay containers
            "div[class*=popup-ad]," +
            "div[class*=pop-up]," +
            "div[class*=popunder]," +
            "div[class*=interstitial]," +
            "div[class*=overlay-ad]," +
            "div[class*=modal-ad]," +
            "div[class*=fullscreen-ad]," +
            "div[class*=sticky-ad]," +
            "div[class*=fixed-ad]," +
            "div[class*=floating-ad]," +
            "div[class*=bottom-ad]," +
            "div[class*=top-ad]," +
            "div[class*=left-ad]," +
            "div[class*=right-ad]," +
            "div[class*=header-ad]," +
            "div[class*=footer-ad]," +
            "div[class*=sidebar-ad]," +
            // Fake download buttons
            "a[class*=download-ad]," +
            "a[class*=fake-download]," +
            "a[class*=ad-download]," +
            "button[class*=download-ad]," +
            "button[class*=fake-download]," +
            "button[class*=ad-download]," +
            "{display:none!important;height:0!important;min-height:0!important;overflow:hidden!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;position:absolute!important;left:-9999px!important;}" +
            "';" +
            "document.head.appendChild(s);" +
            "}catch(e){}})()",
            null,
        )
    }

    // YouTube ad skip/speed manipulation REMOVED for YouTube ToS compliance.

    /**
     * Block known ad elements via JavaScript injection.
     * More targeted than CSS — removes elements from DOM.
     * Only runs on non-YouTube pages to avoid breaking YouTube.
     */
    private fun applyDomBlocking() {
        if (!blockerEnabled) return
        evaluateJavascript(
            "(function(){try{" +
            "var url=window.location.href;" +
            "if(url.indexOf('youtube.com')>=0||url.indexOf('youtu.be')>=0)return;" +
            // Remove ad iframes
            "var iframes=document.querySelectorAll('iframe');" +
            "for(var i=0;i<iframes.length;i++){" +
            "var f=iframes[i];" +
            "var src=(f.src||'').toLowerCase();" +
            "var cls=(f.className||'').toLowerCase();" +
            "var id=(f.id||'').toLowerCase();" +
            "if(src.indexOf('doubleclick')>=0||src.indexOf('googlesyndication')>=0||" +
            "src.indexOf('googleadservices')>=0||src.indexOf('adnxs')>=0||" +
            "src.indexOf('ad.')>=0||src.indexOf('ads.')>=0||" +
            "cls.indexOf('ad')>=0||id.indexOf('ad')>=0){" +
            "f.parentNode.removeChild(f);" +
            "}" +
            "}" +
            // Remove ad divs
            "var adDivs=document.querySelectorAll('div[class*=ad-],div[id*=ad-],div[data-ad]');" +
            "for(var j=0;j<adDivs.length;j++){" +
            "var d=adDivs[j];" +
            "if(d.tagName==='VIDEO'||d.tagName==='AUDIO')continue;" +
            "if(d.querySelector('video')||d.querySelector('audio'))continue;" +
            "d.parentNode.removeChild(d);" +
            "}" +
            "}catch(e){}})()",
            null,
        )
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
            lowerQuery.contains("vpaid")) {
            // Don't block YouTube's internal VAST handling
            if (!lowerUrl.contains("youtube.com") && !lowerUrl.contains("youtu.be")) {
                return true
            }
        }

        return false
    }

    private fun isAllowedHost(host: String): Boolean {
        val h = host.lowercase(Locale.US)
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
        endedReported = false
        loadUrl(url)
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
              var v=document.querySelector('video');
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
        evaluateJavascript(
            """
            (function(){
              try {
                var v=document.querySelector('video');
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
                        "(function(){var v=document.querySelector('video');if(!v){return 'none';}v.muted=false;v.volume=1;var p=v.play();return 'playing';})()",
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

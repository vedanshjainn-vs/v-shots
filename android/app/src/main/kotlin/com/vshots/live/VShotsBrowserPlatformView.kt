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

private class VShotsBackgroundMediaWebView(
    context: Context,
    private val events: MethodChannel,
) : WebView(context) {

    private val appContext = context.applicationContext
    private val handler = Handler(Looper.getMainLooper())
    private var blockerEnabled = true
    private val blockedHosts = mutableSetOf<String>()
    private val essentialHosts = mutableSetOf<String>()
    private val adUrlPatterns = mutableListOf<String>()
    private var popupBlockedCount = 0
    private var endedReported = false
    private var nearEndReported = false
    private var adActive = false
    private var adJustEndedAt = 0L
    private var adAssistEnabled = true

    var mediaPlaying: Boolean = false
        private set

    private val playbackPoll = object : Runnable {
        override fun run() {
            if (!isAttachedToWindow && !mediaPlaying) return
            evaluateJavascript(YT_POLL_JS) { result ->
                handlePollResult(cleanJsResult(result))
            }
            handler.postDelayed(this, 1000L)
        }
    }

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
                    adJustEndedAt = android.os.SystemClock.elapsedRealtime()
                    setAdActive(false)
                    runResumeAfterAd()
                }
                when (state) {
                    "nearend" -> {
                        if (isYouTube && !nearEndReported) {
                            nearEndReported = true
                            events.invokeMethod("videoEnded", null)
                        }
                        setMediaPlaying(true)
                    }
                    "ended" -> {
                        if (isYouTube && !adActive && !endedReported) {
                            endedReported = true
                            events.invokeMethod("videoEnded", null)
                        }
                        setMediaPlaying(false)
                    }
                    "playing" -> setMediaPlaying(true)
                    "paused" -> {
                        val sinceAd = if (adJustEndedAt == 0L) Long.MAX_VALUE
                        else android.os.SystemClock.elapsedRealtime() - adJustEndedAt
                        if (sinceAd in 0..6000) runResumeAfterAd() else setMediaPlaying(false)
                    }
                    else -> Unit
                }
            }
        }
    }

    private fun setAdActive(value: Boolean) {
        if (adActive == value) return
        adActive = value
        events.invokeMethod("adState", value)
    }

    private fun runAdAssist() {
        evaluateJavascript(YT_AD_ASSIST_JS) { result ->
            Log.d(TAG, "ad assist: ${cleanJsResult(result)}")
        }
    }

    private fun runResumeAfterAd() {
        evaluateJavascript(YT_RESUME_JS) { result ->
            Log.d(TAG, "post-ad resume: ${cleanJsResult(result)}")
        }
    }

    init {
        // Keep the MethodChannel reachable by the foreground playback service
        // for the entire lifetime of this native browser session. Without this
        // assignment notification actions were silently dropped when the
        // notification service was invoked outside the Flutter UI tree.
        VShotsBrowserPlaybackService.eventChannel = events
        setBackgroundColor(Color.BLACK)
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.mediaPlaybackRequiresUserGesture = false
        settings.loadsImagesAutomatically = true
        settings.javaScriptCanOpenWindowsAutomatically = false
        settings.setSupportMultipleWindows(false)
        CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
        webChromeClient = object : WebChromeClient() {
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
                events.invokeMethod("pageStarted", null)
            }
            override fun onPageFinished(view: WebView?, url: String?) {
                events.invokeMethod("pageFinished", null)
                startPlaybackPolling()
                attemptAutoplayWithAudio()
            }
            override fun onReceivedError(
                view: WebView?, request: WebResourceRequest?, error: WebResourceError?
            ) {
                if (request?.isForMainFrame != false) {
                    events.invokeMethod("error", "Playback failed — please retry")
                }
            }
            override fun shouldInterceptRequest(
                view: WebView?, request: WebResourceRequest?
            ): WebResourceResponse? {
                return try {
                    val url = request?.url ?: return null
                    val urlStr = url.toString()
                    if (!blockerEnabled) return null
                    val host = url.host?.lowercase(Locale.US) ?: return null
                    val path = url.path?.lowercase(Locale.US) ?: ""
                    val query = url.query?.lowercase(Locale.US) ?: ""
                    if (isYouTubeDomain(host) || isYouTubeAdNetwork(host)) return null
                    if (matchesAnyHost(host, essentialHosts)) return null
                    if (matchesAnyHost(host, blockedHosts)) {
                        reportBlock(host)
                        return emptyResponse()
                    }
                    if (matchesAdPattern(urlStr, path, query)) {
                        reportBlock(host)
                        return emptyResponse()
                    }
                    null
                } catch (_: Throwable) { null }
            }
            private fun isYouTubeDomain(host: String): Boolean {
                val domains = listOf(
                    "youtube.com", "www.youtube.com", "m.youtube.com", "youtube-nocookie.com",
                    "youtu.be", "ytimg.com", "yt3.ggpht.com", "yt3.googleusercontent.com",
                    "youtube-ui.l.google.com", "youtubeembedded-pa.googleapis.com",
                    "youtube.googleapis.com", "googlevideo.com"
                )
                return domains.any { host == it || host.endsWith(".$it") }
            }
            private fun isYouTubeAdNetwork(host: String): Boolean {
                val networks = listOf("doubleclick.net", "googlesyndication.com", "googleadservices.com")
                return networks.any { host == it || host.endsWith(".$it") }
            }
        }
    }

    fun setContentBlocker(
        enabled: Boolean,
        blocked: List<String>,
        essential: List<String>,
        patterns: List<String>,
    ) {
        blockerEnabled = enabled
        blockedHosts.clear(); blockedHosts.addAll(blocked.map { it.lowercase(Locale.US) })
        essentialHosts.clear(); essentialHosts.addAll(essential.map { it.lowercase(Locale.US) })
        adUrlPatterns.clear(); adUrlPatterns.addAll(patterns.map { it.lowercase(Locale.US) })
    }

    fun setAdAssist(enabled: Boolean) { adAssistEnabled = enabled }

    fun loadUrlSafe(value: String) {
        endedReported = false
        nearEndReported = false
        adActive = false
        adJustEndedAt = 0L
        loadUrl(value)
    }

    fun setMediaPlaying(value: Boolean) {
        mediaPlaying = value
        startPlaybackForegroundService(playing = value)
        events.invokeMethod("playbackState", value)
    }

    fun updateNotification(title: String, artist: String, playing: Boolean) {
        startPlaybackForegroundService(title = title, artist = artist, playing = playing)
    }

    private fun startPlaybackForegroundService(
        title: String? = null,
        artist: String? = null,
        playing: Boolean = mediaPlaying,
    ) {
        val intent = Intent(appContext, VShotsBrowserPlaybackService::class.java).apply {
            action = VShotsBrowserPlaybackService.ACTION_UPDATE
            putExtra("title", title ?: "V Shots")
            putExtra("artist", artist ?: "Music playback")
            putExtra("playing", playing)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) appContext.startForegroundService(intent)
            else appContext.startService(intent)
        } catch (t: Throwable) {
            Log.w(TAG, "Unable to start playback notification service", t)
        }
    }

    private fun updatePlaybackNotification(playing: Boolean) {
        startPlaybackForegroundService(playing = playing)
    }

    private fun stopPlaybackForegroundService() {
        try { appContext.stopService(Intent(appContext, VShotsBrowserPlaybackService::class.java)) }
        catch (_: Throwable) {}
    }

    fun disposeMedia() {
        stopPlaybackPolling()
        stopPlaybackForegroundService()
        if (VShotsBrowserPlaybackService.eventChannel === events) {
            VShotsBrowserPlaybackService.eventChannel = null
        }
        mediaPlaying = false
        stopLoading()
        loadUrl("about:blank")
    }

    private fun startPlaybackPolling() {
        handler.removeCallbacks(playbackPoll)
        handler.post(playbackPoll)
    }

    private fun stopPlaybackPolling() { handler.removeCallbacks(playbackPoll) }

    private fun attemptAutoplayWithAudio() {
        evaluateJavascript("(function(){try{var v=document.querySelector('video,audio'); if(v){v.muted=false;v.volume=1;var p=v.play();if(p&&p.catch)p.catch(function(){});}return 'ok';}catch(e){return 'err';}})()", null)
    }

    private fun cleanJsResult(result: String): String = result.trim('"')

    private fun matchesAnyHost(host: String, set: Set<String>): Boolean =
        set.any { host == it || host.endsWith(".$it") }

    private fun matchesAdPattern(url: String, path: String, query: String): Boolean =
        adUrlPatterns.any { token -> url.lowercase(Locale.US).contains(token) || path.contains(token) || query.contains(token) }

    private fun reportBlock(host: String) { events.invokeMethod("blocked", host) }

    private fun emptyResponse(): WebResourceResponse =
        WebResourceResponse("text/plain", "utf-8", ByteArrayInputStream(ByteArray(0)))

    override fun onVisibilityChanged(changedView: View?, visibility: Int) {
        super.onVisibilityChanged(changedView, visibility)
        if (visibility == View.VISIBLE || mediaPlaying) {
            startPlaybackPolling()
        }
    }

    override fun onDetachedFromWindow() {
        // Keep playback polling alive while the WebView remains the active
        // media owner. The Flutter PlatformView is intentionally long-lived.
        super.onDetachedFromWindow()
    }

    fun invokeMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "load" -> {
                val url = call.arguments as? String
                if (url.isNullOrBlank()) result.error("BAD_URL", "Missing URL", null)
                else { loadUrlSafe(url); result.success(null) }
            }
            "reload" -> { reload(); result.success(null) }
            "play" -> { attemptAutoplayWithAudio(); result.success(null) }
            "pause" -> {
                evaluateJavascript("(function(){try{var v=document.querySelector('video,audio');if(v)v.pause();return 'ok';}catch(e){return 'err';}})()", null)
                setMediaPlaying(false)
                result.success(null)
            }
            "toggle" -> {
                evaluateJavascript("(function(){try{var v=document.querySelector('video,audio');if(!v)return 'none';if(v.paused){v.muted=false;v.volume=1;var p=v.play();if(p&&p.catch)p.catch(function(){});return 'playing';}v.pause();return 'paused';}catch(e){return 'err';}})()") { state ->
                    setMediaPlaying(cleanJsResult(state) == "playing")
                    result.success(cleanJsResult(state))
                }
            }
            "setContentBlocker" -> {
                val args = call.arguments as? Map<*, *>
                val enabled = args?.get("enabled") as? Boolean ?: true
                val blocked = (args?.get("blocked") as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList()
                val essential = (args?.get("essential") as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList()
                val patterns = (args?.get("patterns") as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList()
                setContentBlocker(enabled, blocked, essential, patterns)
                result.success(null)
            }
            "setAdAssist" -> {
                setAdAssist((call.arguments as? Boolean) ?: true)
                result.success(null)
            }
            "updateNotification" -> {
                val args = call.arguments as? Map<*, *>
                val title = args?.get("title")?.toString() ?: "V Shots"
                val artist = args?.get("artist")?.toString() ?: "Music playback"
                val playing = args?.get("playing") as? Boolean ?: true
                updateNotification(title, artist, playing)
                result.success(null)
            }
            "dispose" -> { disposeMedia(); result.success(null) }
            else -> result.notImplemented()
        }
    }
}

private class VShotsBrowserPlatformViewFactory(private val messenger: io.flutter.plugin.common.BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val channel = MethodChannel(messenger, "vshots/browser/$viewId")
        val view = VShotsBackgroundMediaWebView(context, channel)
        channel.setMethodCallHandler { call, result -> view.invokeMethod(call, result) }
        return object : PlatformView {
            override fun getView(): View = view
            override fun dispose() { view.disposeMedia(); channel.setMethodCallHandler(null) }
        }
    }
}

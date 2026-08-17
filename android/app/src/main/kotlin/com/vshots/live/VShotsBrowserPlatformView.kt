package com.vshots.live

import android.content.Context
import android.content.Intent
import android.graphics.Color
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
 * Discovery-only native browser view.
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

    // ── General content blocker (domain-agnostic) ─────────────────────────
    // Populated from Dart via "setContentBlocker". Host-exact + suffix
    // matching only — no regex, no website-specific rules. Essential/allow
    // hosts always pass (media must never be blocked).
    private var blockerEnabled = true
    private val blockedHosts = mutableSetOf<String>()
    private val essentialHosts = mutableSetOf<String>()
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
        CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
        webChromeClient = WebChromeClient()

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

            override fun shouldInterceptRequest(
                view: WebView?,
                request: WebResourceRequest?,
            ): WebResourceResponse? {
                val url = request?.url ?: return null
                if (!blockerEnabled) return null
                val host = url.host?.lowercase(Locale.US) ?: return null
                // First-party safety + player-essential media: never block.
                if (matchesAny(host, essentialHosts)) return null
                if (!matchesAny(host, blockedHosts)) return null
                // Block with an empty response; report to Dart for stats.
                events.invokeMethod("blocked", host)
                return WebResourceResponse(
                    "text/plain",
                    "utf-8",
                    ByteArrayInputStream(ByteArray(0)),
                )
            }

            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?,
            ): Boolean {
                return request?.url?.host?.let(::isAllowedHost) != true
            }
        }
    }

    /** Host == rule or endsWith ".rule" (e.g. "doubleclick.net" also matches
     *  "ad.doubleclick.net"). Conservative: no substring matching. */
    private fun matchesAny(host: String, rules: Set<String>): Boolean {
        for (rule in rules) {
            if (host == rule || host.endsWith(".$rule")) return true
        }
        return false
    }

    private fun isAllowedHost(host: String): Boolean {
        val h = host.lowercase(Locale.US)
        val allowed = listOf(
            "youtube.com",
            "youtu.be",
            "googlevideo.com",
            "ytimg.com",
            "google.com",
            "gstatic.com",
            "ggpht.com",
        )
        return allowed.any { h == it || h.endsWith(".$it") }
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
    ) {
        blockerEnabled = enabled
        blockedHosts.clear()
        blockedHosts.addAll(blocked.map { it.lowercase(Locale.US) })
        essentialHosts.clear()
        essentialHosts.addAll(essential.map { it.lowercase(Locale.US) })
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
                "play" -> {
                    webView.evaluateJavascript(
                        "(function(){var v=document.querySelector('video');if(!v){return 'none';}v.muted=false;v.volume=1;var p=v.play();return 'playing';})()",
                    ) { value ->
                        webView.setMediaPlaying(clean(value) == "playing")
                    }
                    result.success(null)
                }
                "setContentBlocker" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val enabled = (args["enabled"] as? Boolean) ?: true
                    val blocked = (args["blocked"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                    val essential = (args["essential"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                    webView.setContentBlocker(enabled, blocked, essential)
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

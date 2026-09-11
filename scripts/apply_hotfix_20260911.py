from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected 1 match, found {count}')
    p.write_text(text.replace(old, new))


# Native browser: never let post-ad/autoplay recovery override an explicit user pause.
native = 'android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlatformView.kt'
replace_once(
    native,
    '    private var adJustEndedAt = 0L\n\n    /** Master switch',
    '    private var adJustEndedAt = 0L\n\n    /** Explicit user pause guard. Recovery/autoplay must never fight the user. */\n    private var userPaused = false\n\n    /** Master switch',
)
replace_once(
    native,
    '    fun load(url: String) {\n        if (!url.startsWith("https://")) return',
    '    fun load(url: String) {\n        if (!url.startsWith("https://")) return',
)
replace_once(
    native,
    '        endedReported = false\n        nearEndReported = false\n        adActive = false\n        adJustEndedAt = 0L\n        loadUrl(url)',
    '        endedReported = false\n        nearEndReported = false\n        adActive = false\n        adJustEndedAt = 0L\n        userPaused = false\n        loadUrl(url)',
)
replace_once(
    native,
    '    fun reloadCurrent() {\n        endedReported = false',
    '    fun reloadCurrent() {\n        userPaused = false\n        endedReported = false',
)
replace_once(
    native,
    '                        if (sinceAd in 0..6000) {\n                            runResumeAfterAd()\n                        } else {',
    '                        if (sinceAd in 0..6000 && !userPaused) {\n                            runResumeAfterAd()\n                        } else {',
)
replace_once(
    native,
    '    private fun attemptAutoplayWithAudio() {\n        // YouTube pages ONLY:',
    '    private fun attemptAutoplayWithAudio() {\n        if (userPaused) return\n        // YouTube pages ONLY:',
)
replace_once(
    native,
    '    override fun onResume() {\n        super.onResume()\n        if (mediaPlaying) attemptAutoplayWithAudio()\n    }',
    '    override fun onResume() {\n        super.onResume()\n        // Do not auto-play after a normal Activity resume. A manual pause is\n        // authoritative; explicit play/notification commands clear userPaused.\n    }',
)
replace_once(
    native,
    '    fun pauseMedia() {\n        evaluateJavascript(',
    '    fun pauseMedia() {\n        userPaused = true\n        evaluateJavascript(',
)
replace_once(
    native,
    '    fun togglePlayback() {\n        evaluateJavascript(',
    '    fun togglePlayback() {\n        evaluateJavascript(',
)
replace_once(
    native,
    "              if(v.paused){\n                v.muted=false; v.volume=1;\n                var p=v.play();\n                return p ? 'playing' : 'playing';\n              }\n              v.pause();\n              return 'paused';",
    "              if(v.paused){\n                v.muted=false; v.volume=1;\n                var p=v.play();\n                return p ? 'playing' : 'playing';\n              }\n              v.pause();\n              return 'paused';",
)
replace_once(
    native,
    '            val state = cleanJsResult(result)\n            setMediaPlaying(state.contains("playing"))\n        }\n    }\n\n    /**\n     * Best-effort autoplay',
    '            val state = cleanJsResult(result)\n            userPaused = !state.contains("playing")\n            setMediaPlaying(state.contains("playing"))\n        }\n    }\n\n    /**\n     * Best-effort autoplay',
)
# Explicit notification Play must clear the pause guard.
replace_once(
    native,
    '                "play" -> {\n                    webView.evaluateJavascript(',
    '                "play" -> {\n                    webView.userPlay()\n                    result.success(null)\n                }\n                "play_legacy" -> {\n                    webView.evaluateJavascript(',
)
# Expose a dedicated explicit-play entry point on the WebView.
replace_once(
    native,
    '    /**\n     * Best-effort autoplay + unmute pass.',
    '    fun userPlay() {\n        userPaused = false\n        evaluateJavascript(\n            "(function(){var v=document.querySelector(\\\'video,audio\\\');if(!v){return \\'none\\\';}v.muted=false;v.volume=1;var p=v.play();return \\'playing\\\';})()",\n        ) { value ->\n            setMediaPlaying(cleanJsResult(value) == "playing")\n        }\n    }\n\n    /**\n     * Best-effort autoplay + unmute pass.',
)
# Discovery: make vertical paging more forgiving and keep the next card warm.
feed = 'lib/features/foryou/for_you_feed_screen.dart'
replace_once(
    feed,
    '              physics: const PageScrollPhysics(),\n              allowImplicitScrolling: false,',
    '              physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),\n              allowImplicitScrolling: true,\n              pageSnapping: true,',
)
# Fast first paint: use the existing lightweight provider before the heavier multi-engine chain.
replace_once(
    feed,
    '    if (source.query == null) {\n      final primaryMood =',
    "    if (source.query == null) {\n      // Fast first batch: get a small playable set immediately from the\n      // existing lightweight provider. The heavier personalization engines\n      // can take over on subsequent batches instead of blocking first paint.\n      try {\n        final fast = await forYouFeedService.fetchNextBatch(\n          excludeIds: _seenIds,\n          count: 8,\n        );\n        if (fast.isNotEmpty) return _refineForMode(source, fast);\n      } catch (e) {\n        debugPrint('[ForYouFeed] fast first batch failed: $e');\n      }\n\n      final primaryMood =",
)

print('Hotfix source changes applied.')

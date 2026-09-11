from pathlib import Path

# One-time runner: applies the 2026-09-11 playback/discovery hotfix.

def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected 1 match, found {count}')
    p.write_text(text.replace(old, new))

native = 'android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlatformView.kt'
replace_once(native, '    private var adJustEndedAt = 0L\n\n    /** Master switch', '    private var adJustEndedAt = 0L\n\n    /** Explicit user pause guard. Recovery/autoplay must never fight the user. */\n    private var userPaused = false\n\n    /** Master switch')
replace_once(native, '        endedReported = false\n        nearEndReported = false\n        adActive = false\n        adJustEndedAt = 0L\n        loadUrl(url)', '        endedReported = false\n        nearEndReported = false\n        adActive = false\n        adJustEndedAt = 0L\n        userPaused = false\n        loadUrl(url)')
replace_once(native, '    fun reloadCurrent() {\n        endedReported = false', '    fun reloadCurrent() {\n        userPaused = false\n        endedReported = false')
replace_once(native, '                        if (sinceAd in 0..6000) {\n                            runResumeAfterAd()\n                        } else {', '                        if (sinceAd in 0..6000 && !userPaused) {\n                            runResumeAfterAd()\n                        } else {')
replace_once(native, '    private fun attemptAutoplayWithAudio() {\n        // YouTube pages ONLY:', '    private fun attemptAutoplayWithAudio() {\n        if (userPaused) return\n        // YouTube pages ONLY:')
replace_once(native, '    override fun onResume() {\n        super.onResume()\n        if (mediaPlaying) attemptAutoplayWithAudio()\n    }', '    override fun onResume() {\n        super.onResume()\n        // Explicit user pause is authoritative; resume only via Play.\n    }')
replace_once(native, '    fun pauseMedia() {\n        evaluateJavascript(', '    fun pauseMedia() {\n        userPaused = true\n        evaluateJavascript(')
replace_once(native, '            val state = cleanJsResult(result)\n            setMediaPlaying(state.contains("playing"))\n        }\n    }\n\n    /**\n     * Best-effort autoplay', '            val state = cleanJsResult(result)\n            userPaused = !state.contains("playing")\n            setMediaPlaying(state.contains("playing"))\n        }\n    }\n\n    fun userPlay() {\n        userPaused = false\n        if (!mediaPlaying) togglePlayback()\n    }\n\n    /**\n     * Best-effort autoplay')
replace_once(native, '                "play" -> {\n                    webView.evaluateJavascript(', '                "play" -> {\n                    webView.userPlay()\n                    result.success(null)\n                }\n                "play_legacy" -> {\n                    webView.evaluateJavascript(')

feed = 'lib/features/foryou/for_you_feed_screen.dart'
replace_once(feed, '              physics: const PageScrollPhysics(),\n              allowImplicitScrolling: false,', '              physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),\n              allowImplicitScrolling: true,\n              pageSnapping: true,')
replace_once(feed, '    if (source.query == null) {\n      final primaryMood =', "    if (source.query == null) {\n      // Fast first batch: use the lightweight provider before the heavier\n      // recommendation chain so first paint is not blocked.\n      try {\n        final fast = await forYouFeedService.fetchNextBatch(\n          excludeIds: _seenIds,\n          count: 8,\n        );\n        if (fast.isNotEmpty) return _refineForMode(source, fast);\n      } catch (e) {\n        debugPrint('[ForYouFeed] fast first batch failed: $e');\n      }\n\n      final primaryMood =")

print('Hotfix source changes applied.')

from pathlib import Path

p = Path('android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlatformView.kt')
s = p.read_text()

old = '''    /** Explicit user pause guard. Polling must never fight the user. */
    private var userPaused = false
'''
new = '''    /** Explicit user pause guard. Polling must never fight the user. */
    private var userPaused = false
    private var unexpectedPauseSinceMs = 0L
    private var pauseRecoveryAttempts = 0
    private var pauseRecoveryInFlight = false
    private val maxPauseRecoveryAttempts = 3
'''
assert old in s
s = s.replace(old, new, 1)

old = '''        adAudioRestoreInFlight = false
        userPaused = !autoplay
        mediaPlaying = false
'''
new = '''        adAudioRestoreInFlight = false
        userPaused = !autoplay
        unexpectedPauseSinceMs = 0L
        pauseRecoveryAttempts = 0
        pauseRecoveryInFlight = false
        mediaPlaying = false
'''
assert old in s
s = s.replace(old, new, 1)

old = '''    private fun handlePollResult(result: String, generation: Long) {
        if (generation != loadGeneration) return
'''
new = '''    private fun recoverUnexpectedPause(generation: Long) {
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
'''
assert old in s
s = s.replace(old, new, 1)

old = '''                    "paused" -> {
                        setAudioState(BrowserAudioState.PAUSED)
                        setPlaybackState("paused", false)
                    }
'''
new = '''                    "paused" -> {
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
'''
assert old in s
s = s.replace(old, new, 1)

old = '''                    "playing" -> {
                        // A poll is read-only. It reports the element's
                        // observed state; it never turns a pause into play.
                        if (!userPaused) {
'''
new = '''                    "playing" -> {
                        unexpectedPauseSinceMs = 0L
                        pauseRecoveryInFlight = false
                        if (!userPaused) {
'''
assert old in s
s = s.replace(old, new, 1)

old = '''        if (userInitiated) userPaused = true
        setAudioState(BrowserAudioState.PAUSED)
'''
new = '''        userPaused = true
        setAudioState(BrowserAudioState.PAUSED)
'''
assert old in s
s = s.replace(old, new, 1)

p.write_text(s)
print('pause recovery patch applied')

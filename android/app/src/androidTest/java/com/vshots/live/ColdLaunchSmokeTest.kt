package com.vshots.live

import android.os.SystemClock
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Cold-launch smoke test for V Shots.
 *
 * Detects the startup crash the user hit on-device (MIUI "app keeps stopping"
 * dialog). It launches the real MainActivity, waits long enough for Flutter to
 * render its first frame and complete the post-frame service bootstrap, then
 * asserts the activity is still alive and RESUMED — i.e. it did NOT crash
 * during cold launch.
 *
 * If the process dies at startup (native crash, fatal Dart exception, or an
 * uncaught error escaping the bootstrap), ActivityScenario.launch throws or the
 * activity leaves RESUMED, and this test FAILS with the crash stack trace —
 * which BrowserStack surfaces in the Espresso build report.
 *
 * NOTE: Launching MainActivity (an AudioServiceActivity) initializes the shared
 * FlutterEngine and the WebView platform view, exactly as the launcher does.
 * This is deliberately a NO-OP test: it makes no UI assertions beyond "the app
 * survives cold launch", which is the exact regression we are guarding.
 */
@RunWith(AndroidJUnit4::class)
@LargeTest
class ColdLaunchSmokeTest {

    @Test
    fun coldLaunch_reachesResumedWithoutCrash() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            // Allow Flutter first frame + the post-frame service bootstrap to
            // complete (and any startup crash to surface) before asserting.
            SystemClock.sleep(12_000L)
            assertEquals(
                "App should survive cold launch without crashing.",
                Lifecycle.State.RESUMED,
                scenario.state,
            )
        }
    }
}

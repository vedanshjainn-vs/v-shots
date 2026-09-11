package com.vshots.live

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Registers the one native browser platform view. Android media controls are
 * owned by VShotsBrowserPlaybackService; no second Android media activity or
 * MediaSession is installed.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "vshots/native_browser",
            VShotsBrowserPlatformViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
    }
}

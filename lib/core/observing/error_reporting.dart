import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Global error reporting bootstrap (Firebase Crashlytics).
///
/// Contract:
/// - NEVER throws and NEVER blocks boot for long: any failure here leaves
///   the app fully functional, just without remote crash reporting.
/// - Framework errors ([FlutterError]) are recorded as NON-fatal (Flutter
///   recovers from them; the console output is preserved in debug).
/// - Uncaught async/zone errors ([PlatformDispatcher.onError]) are recorded
///   as non-fatal too, because returning `true` means the app survives.
///   True native crashes (process death) are captured by the SDK as fatal.
/// - Debug builds keep collection DISABLED so local dev does not pollute
///   the Crashlytics dashboard.
Future<void> initializeErrorReporting() async {
  // Install the hooks first so nothing is lost while Firebase initializes.
  FlutterError.onError = (FlutterErrorDetails details) {
    // Preserve the default console presentation for developers.
    FlutterError.presentError(details);
    _record(() =>
        FirebaseCrashlytics.instance.recordFlutterError(details, fatal: false));
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _record(() => FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: 'uncaught async error',
          fatal: false,
        ));
    // Returning true keeps the app alive (handled).
    return true;
  };

  try {
    // Binds to the native default app created by the google-services plugin
    // from android/app/google-services.json (no options needed on Android).
    await Firebase.initializeApp();
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
    debugPrint('[ErrorReporting] Crashlytics ready '
        '(collection ${kDebugMode ? 'disabled in debug' : 'enabled'})');
  } catch (e, s) {
    // Degrade gracefully: the app boots normally without reporting.
    debugPrint('[ErrorReporting] init failed — continuing without it: $e');
    debugPrint('[ErrorReporting] init stack: $s');
  }
}

/// Fire-and-forget record that can never itself throw (would recurse).
Future<void> _record(Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    // Swallow silently: reporting must never take the app down.
    debugPrint('[ErrorReporting] record failed: $e');
  }
}

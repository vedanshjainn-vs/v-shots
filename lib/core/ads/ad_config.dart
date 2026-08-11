// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Configuration
//
// Ads use Google AdMob NATIVE ads. Development builds use Google's official
// TEST ad unit IDs; PRODUCTION IDs are injected at build time via secure
// configuration (GitHub Actions secrets -> .env -> flutter_dotenv). Real ad
// IDs are NEVER committed to source control.
//
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central ad configuration. Switches between test and production IDs based
/// on whether production IDs have been injected.
class AdConfig {
  AdConfig._();

  /// Official Google TEST ad unit ID for native ads on Android.
  static const String testNativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';

  /// Whether AdMob is enabled at all. Toggled off for store/developer builds
  /// where no production config is present, so ads never show placeholder/test
  /// content to real users.
  static bool get adsEnabled {
    final prod = _prodNativeAdUnitId;
    return prod != null && prod.isNotEmpty;
  }

  static String? get _prodNativeAdUnitId {
    if (dotenv.isInitialized) {
      final fromEnv = dotenv.maybeGet('ADMOB_NATIVE_AD_ID');
      if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    }
    const compileTime = String.fromEnvironment('ADMOB_NATIVE_AD_ID');
    if (compileTime.isNotEmpty) return compileTime;
    return null;
  }

  /// The native ad unit ID actually used at runtime: production when
  /// configured, otherwise the official Google test ID (never shown to real
  /// users unless ads are explicitly enabled in a dev build).
  static String get nativeAdUnitId => _prodNativeAdUnitId ?? testNativeAdUnitId;

  /// Ad placement cadence: insert an ad after roughly this many organic items.
  static const int homeAdEvery = 8;
  static const int searchAdEvery = 8;

  /// If true, real-user builds should be treated as test devices for AdMob.
  /// Production builds should keep this false.
  static bool get isTestMode => !adsEnabled;
}

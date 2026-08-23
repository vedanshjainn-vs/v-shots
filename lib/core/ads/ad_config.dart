// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Configuration
//
// Ads use Google AdMob. Supported formats: native, interstitial, rewarded,
// banner. Development builds use Google's official TEST ad unit IDs;
// PRODUCTION IDs are injected at build time via secure configuration
// (GitHub Actions secrets -> .env -> flutter_dotenv). Real ad IDs are NEVER
// committed to source control.
//
// Modes:
//   OFF  — no production IDs injected (store/developer default): no ads.
//   TEST — ADMOB_TEST_MODE=true (debug builds only): ads ON with official
//          Google TEST IDs. The only way developers can see ads locally.
//   PROD — any production unit ID injected: ads ON with production IDs.
//
// All ON/OFF decisions live in AdPolicy — this class is the ID source only.
//
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central ad configuration. Switches between test and production IDs based
/// on whether production IDs have been injected.
class AdConfig {
  AdConfig._();

  // ── Official Google TEST ad unit IDs (Android) — safe for development ──
  static const String testNativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  // ── Master switch ───────────────────────────────────────────────────────

  /// Whether AdMob is enabled at all. True when ANY production unit ID is
  /// injected, or in a debug build with ADMOB_TEST_MODE=true (test IDs).
  /// Toggled off for store/developer builds where no production config is
  /// present, so ads never show placeholder/test content to real users.
  static bool get adsEnabled => _hasAnyAdUnitIdChecked || devTestMode;

  /// True when at least one production unit ID was injected at build time.
  static bool get hasAnyAdUnitId =>
      _prod('ADMOB_NATIVE_AD_ID') != null ||
      _prod('ADMOB_INTERSTITIAL_AD_ID') != null ||
      _prod('ADMOB_REWARDED_AD_ID') != null ||
      _prod('ADMOB_BANNER_AD_ID') != null;

  /// Development test mode: official Google TEST ads, debug builds only.
  /// Enabled by ADMOB_TEST_MODE=true in .env (or --dart-define).
  static bool get devTestMode {
    if (!kDebugMode) return false;
    return _flag('ADMOB_TEST_MODE');
  }

  /// True when the app is currently running with TEST ad unit IDs (i.e. no
  /// production IDs injected). Developer diagnostic — logged at boot in
  /// debug builds, never shown to users.
  static bool get isTestMode => !hasAnyAdUnitId;

  // ── Per-format unit IDs (production when injected, test otherwise) ─────

  static String get nativeAdUnitId =>
      _prod('ADMOB_NATIVE_AD_ID') ?? testNativeAdUnitId;
  static String get interstitialAdUnitId =>
      _prod('ADMOB_INTERSTITIAL_AD_ID') ?? testInterstitialAdUnitId;
  static String get rewardedAdUnitId =>
      _prod('ADMOB_REWARDED_AD_ID') ?? testRewardedAdUnitId;
  static String get bannerAdUnitId =>
      _prod('ADMOB_BANNER_AD_ID') ?? testBannerAdUnitId;

  // ── Placement cadence (native in-feed spacing — see each screen) ───────

  /// Ad placement cadence: insert an ad after roughly this many organic items.
  static const int homeAdEvery = 8;
  static const int searchAdEvery = 8;

  /// Insert one clearly-separated Discovery ad page after this many organic
  /// videos (Section 7: ~8-10 videos, never over the player).
  static const int discoveryAdEvery = 9;

  /// Playlist pages: one native card after this many tracks (max 1/page).
  static const int playlistAdAfter = 10;

  // ── Internals ───────────────────────────────────────────────────────────

  static String? _prod(String key) {
    if (dotenv.isInitialized) {
      final fromEnv = dotenv.maybeGet(key);
      if (fromEnv != null && fromEnv.trim().isNotEmpty) return fromEnv.trim();
    }
    const String ct1 = String.fromEnvironment('ADMOB_NATIVE_AD_ID');
    const String ct2 = String.fromEnvironment('ADMOB_INTERSTITIAL_AD_ID');
    const String ct3 = String.fromEnvironment('ADMOB_REWARDED_AD_ID');
    const String ct4 = String.fromEnvironment('ADMOB_BANNER_AD_ID');
    switch (key) {
      case 'ADMOB_NATIVE_AD_ID':
        return ct1.isNotEmpty ? ct1 : null;
      case 'ADMOB_INTERSTITIAL_AD_ID':
        return ct2.isNotEmpty ? ct2 : null;
      case 'ADMOB_REWARDED_AD_ID':
        return ct3.isNotEmpty ? ct3 : null;
      case 'ADMOB_BANNER_AD_ID':
        return ct4.isNotEmpty ? ct4 : null;
    }
    return null;
  }

  static bool _flag(String key) {
    if (dotenv.isInitialized) {
      final fromEnv = dotenv.maybeGet(key);
      if (fromEnv != null && fromEnv.trim().isNotEmpty) {
        return fromEnv.trim() == 'true' || fromEnv.trim() == '1';
      }
    }
    const String ct1 = String.fromEnvironment('ADMOB_TEST_MODE');
    if (key == 'ADMOB_TEST_MODE' && (ct1 == 'true' || ct1 == '1')) return true;
    return false;
  }

  static bool? _debugHasAnyAdUnitId;

  /// @visibleForTesting — force the master ID-presence check (tests only).
  @visibleForTesting
  static void debugSetHasAnyAdUnitId(bool? value) {
    _debugHasAnyAdUnitId = value;
  }

  static bool get _hasAnyAdUnitIdChecked {
    final override = _debugHasAnyAdUnitId;
    if (override != null) return override;
    return hasAnyAdUnitId;
  }
}

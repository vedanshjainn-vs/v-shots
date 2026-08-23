// ═════════════════════════════════════════════════════════════════════════
// V Shots — AdManager
//
// Initializes Google Mobile Ads and the UMP consent flow ONCE at app startup.
// Ads are only enabled when production ad IDs are configured (AdConfig) or
// a debug build runs in test mode (ADMOB_TEST_MODE).
//
// PERFORMANCE RULE: main() fires initialize() WITHOUT awaiting it — ad init
// must never block first paint. Placements that need the SDK await
// [waitForReady] (bounded, fail-safe).
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_analytics.dart';
import 'ad_config.dart';
import 'consent_manager.dart';

class AdManager {
  AdManager._();

  static final AdManager instance = AdManager._();

  bool _initialized = false;
  final Completer<void> _ready = Completer<void>();

  bool get isInitialized => _initialized;

  /// Initializes consent + MobileAds. Safe to call multiple times; only runs
  /// the real work once. Does nothing (and completes [waitForReady]) when
  /// ads are not enabled.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!AdConfig.adsEnabled) {
      _completeReady();
      return;
    }
    // Consent first (UMP requirement), then SDK init.
    await ConsentManager.instance.initialize();
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      // Fail-safe: SDK init failure ⇒ every ad placement degrades to the
      // normal UI (loads will simply fail). App never breaks.
      debugPrint('[AdManager] MobileAds init error: $e');
      AdAnalytics.log('ad_load_failed', detail: 'MobileAds.initialize');
    }
    _completeReady();
    if (kDebugMode) {
      debugPrint(
          '[Ads] mode=${AdConfig.isTestMode ? 'TEST (test IDs, debug only)' : 'PROD (injected IDs)'}'
          ' native=${AdConfig.nativeAdUnitId}'
          ' interstitial=${AdConfig.interstitialAdUnitId}'
          ' rewarded=${AdConfig.rewardedAdUnitId}'
          ' banner=${AdConfig.bannerAdUnitId}');
    }
  }

  void _completeReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Bounded wait for SDK readiness. NEVER throws, never blocks startup:
  /// on timeout the caller simply proceeds with normal (ad-less) behavior.
  Future<void> waitForReady({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      await _ready.future.timeout(timeout);
    } on TimeoutException {
      // fall through — caller checks isInitialized
    }
  }
}

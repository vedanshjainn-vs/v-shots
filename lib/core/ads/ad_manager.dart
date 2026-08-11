// ═════════════════════════════════════════════════════════════════════════
// V Shots — AdManager
//
// Initializes Google Mobile Ads and the UMP consent flow once at app startup.
// Ads are only enabled when production ad IDs are configured (AdConfig).
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'consent_manager.dart';

class AdManager {
  AdManager._();

  static final AdManager instance = AdManager._();

  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Initializes consent + MobileAds. Safe to call multiple times; only runs
  /// the real work once. Does nothing when ads are not enabled.
  Future<void> initialize() async {
    if (_initialized || !AdConfig.adsEnabled) return;
    _initialized = true;
    // Consent first (UMP requirement), then SDK init.
    await ConsentManager.instance.initialize();
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('[AdManager] MobileAds init error: $e');
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Policy (centralized ad configuration & decision engine)
//
// THE single place that decides whether any ad may show. Screens and widgets
// call AdPolicy — they never initialize or manage ad SDKs directly.
//
// Central configuration (per spec):
//   master switch ........ LevelPlay configured in this build (LevelPlayConfig)
//   emergency kill switch  remote feature flag 'enable_ads' (Supabase admin)
//   test / production .... MAX session test mode (test devices) vs live
//   per-format toggles .... native/interstitial/rewarded/banner (below)
//   frequency ............. AdFrequencyController (cooldowns + session caps)
//   premium / ad-free ..... AdFreeManager (temporary pass + future premium)
//   consent ............... ConsentManager (UMP) — never bypassed; pushed
//                           into LevelPlay via VShotsLevelPlay.syncConsent
//
// Every gate fails CLOSED: any missing/failed check ⇒ no ad ⇒ normal UI.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'mrec_ad_manager.dart';
import 'ad_free_manager.dart';
import 'ad_frequency_controller.dart';
import 'consent_manager.dart';
import 'levelplay_config.dart';
import '../remote_config/remote_feature_flags.dart';

/// Every ad placement in the app, identified for policy + analytics.
enum AdPlacement {
  home,
  forYouFeed,
  search,
  playlist,
  library,
  player;

  String get key => name;

  /// MREC (300x250): allowed in all major placements.
  bool canShowMREC(MRECPlacement placement) {
    if (!adsAvailable || !_bannersEnabled) return false;
    return true;
  }
}

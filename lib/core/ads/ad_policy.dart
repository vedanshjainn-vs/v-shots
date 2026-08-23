// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Policy (centralized ad configuration & decision engine)
//
// THE single place that decides whether any ad may show. Screens and widgets
// call AdPolicy — they never initialize or manage ad SDKs directly.
//
// Central configuration (per spec):
//   master switch ........ MAX configured in this build (MaxConfig)
//   emergency kill switch  remote feature flag 'enable_ads' (Supabase admin)
//   test / production .... MAX session test mode (test devices) vs live
//   per-format toggles .... native/interstitial/rewarded/banner (below)
//   frequency ............. AdFrequencyController (cooldowns + session caps)
//   premium / ad-free ..... AdFreeManager (temporary pass + future premium)
//   consent ............... ConsentManager (UMP) — never bypassed; pushed
//                           into MAX via VShotsMax.syncConsent
//
// Every gate fails CLOSED: any missing/failed check ⇒ no ad ⇒ normal UI.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_free_manager.dart';
import 'ad_frequency_controller.dart';
import 'consent_manager.dart';
import 'max_config.dart';
import 'max_sdk_service.dart';
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
}

class AdPolicy {
  AdPolicy._();

  static final AdPolicy instance = AdPolicy._();

  /// Interrupting-format controller: interstitial cooldown (180 s), session
  /// cap (4), minimum foreground dwell (60 s).
  AdFrequencyController frequency = AdFrequencyController();

  // ── In-feed native cadence (Home shelves) ───────────────────────────────
  /// Home: the first native ad appears only AFTER this many organic shelves
  /// — never immediately when Home opens.
  static const int homeFirstAdAfterShelves = 3;

  /// Home: subsequent native ads this many shelves apart (no two ads
  /// adjacent, conservative density).
  static const int homeAdEveryShelves = 4;

  // ── Per-format toggles (defaults; remote/owner can flip later) ─────────
  bool _nativeEnabled = true;
  bool _interstitialEnabled = true;
  bool _rewardedEnabled = true;
  bool _bannersEnabled = true;

  bool get nativeEnabled => _nativeEnabled;
  bool get interstitialEnabled => _interstitialEnabled;
  bool get rewardedEnabled => _rewardedEnabled;
  bool get bannersEnabled => _bannersEnabled;

  /// @visibleForTesting — and the seam for future remote-config wiring.
  @visibleForTesting
  void setFormatEnabled({
    bool? native,
    bool? interstitial,
    bool? rewarded,
    bool? banners,
  }) {
    if (native != null) _nativeEnabled = native;
    if (interstitial != null) _interstitialEnabled = interstitial;
    if (rewarded != null) _rewardedEnabled = rewarded;
    if (banners != null) _bannersEnabled = banners;
  }

  // ── Master gate ─────────────────────────────────────────────────────────

  /// True when ads may be shown to this user AT ALL right now.
  ///
  /// Fails closed on: MAX not configured (no SDK key/unit IDs in this
  /// build), emergency remote flag OFF, user is ad-free (premium /
  /// rewarded pass), or UMP consent still pending.
  bool get adsAvailable {
    if (!MaxConfig.isConfigured) return false;
    if (RemoteFeatureFlags.instance.value('enable_ads', defaultValue: true) ==
        false) {
      return false; // EMERGENCY KILL SWITCH (Supabase feature_flags)
    }
    if (AdFreeManager.instance.isAdFree) return false;
    if (ConsentManager.instance.status == ConsentStatus.required) {
      return false; // consent form pending — never push ads before a decision
    }
    return true;
  }

  // ── Placement gates ─────────────────────────────────────────────────────

  /// Native (in-feed) ads: cadence is enforced by the PLACEMENT (index
  /// spacing in each screen); this gate only checks availability + format.
  bool canShowNative(AdPlacement placement) => adsAvailable && _nativeEnabled;

  /// Interstitials: availability + format + frequency (cooldown/caps/dwell).
  /// Does NOT consume the frequency budget — the caller records a real show
  /// via [frequency.recordShown].
  bool canShowInterstitial() =>
      adsAvailable && _interstitialEnabled && frequency.canShow();

  /// Rewarded: user-initiated ONLY (see VShotsAds.showRewarded — there is no
  /// API to trigger a rewarded ad without a user action).
  bool canShowRewarded() => adsAvailable && _rewardedEnabled;

  /// Banners/MREC: only in placements where they fit the existing layout.
  bool canShowBanner(AdPlacement placement) {
    if (!adsAvailable || !_bannersEnabled) return false;
    return placement == AdPlacement.playlist ||
        placement == AdPlacement.library;
  }

  // ── Diagnostics (debug builds only — never surfaced to users) ──────────

  String describe() {
    final mode = MaxConfig.isConfigured
        ? (VShotsMax.instance.sdkTestMode == true ? 'TEST' : 'PROD')
        : 'OFF';
    return 'AdPolicy mode=$mode '
        'native=$_nativeEnabled interstitial=$_interstitialEnabled '
        'rewarded=$_rewardedEnabled banners=$_bannersEnabled '
        'adFree=${AdFreeManager.instance.isAdFree} '
        'consent=${ConsentManager.instance.status.name} '
        'interstitialsShown=${frequency.shownThisSession}';
  }
}

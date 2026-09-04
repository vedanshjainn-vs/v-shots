// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Policy (centralized ad configuration & decision engine)
//
// THE single place that decides whether any ad may show. Screens and widgets
// call AdPolicy — they never initialize or manage ad SDKs directly.
//
// Every gate fails CLOSED: any missing/failed check ⇒ no ad ⇒ normal UI.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_free_manager.dart';
import 'ad_frequency_controller.dart';
import 'consent_manager.dart';
import 'mrec_ad_manager.dart';
import 'levelplay_config.dart';
import '../remote_config/remote_feature_flags.dart';

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

  AdFrequencyController frequency = AdFrequencyController();

  // In-feed MREC cadence: denser than before, but never at the top of Home.
  static const int homeFirstAdAfterShelves = 3;
  static const int homeAdEveryShelves = 3;

  bool _nativeEnabled = true;
  bool _interstitialEnabled = true;
  bool _rewardedEnabled = true;
  bool _bannersEnabled = true;

  bool get nativeEnabled => _nativeEnabled;
  bool get interstitialEnabled => _interstitialEnabled;
  bool get rewardedEnabled => _rewardedEnabled;
  bool get bannersEnabled => _bannersEnabled;

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

  bool get adsAvailable {
    if (!LevelPlayConfig.isConfigured) return false;
    if (RemoteFeatureFlags.instance.value('enable_ads', defaultValue: true) ==
        false) {
      return false;
    }
    if (AdFreeManager.instance.isAdFree) return false;
    if (ConsentManager.instance.status == ConsentStatus.required) {
      return false;
    }
    return true;
  }

  bool canShowNative(AdPlacement placement) => adsAvailable && _nativeEnabled;

  bool canShowInterstitial() =>
      adsAvailable && _interstitialEnabled && frequency.canShow();

  bool canShowRewarded() => adsAvailable && _rewardedEnabled;

  bool canShowBanner(AdPlacement placement) {
    if (!adsAvailable || !_bannersEnabled) return false;
    return placement == AdPlacement.playlist ||
        placement == AdPlacement.library;
  }

  String describe() {
    final mode = LevelPlayConfig.isConfigured
        ? (LevelPlayConfig.usingTestCredentials ? 'TEST' : 'PROD')
        : 'OFF';
    return 'AdPolicy mode=$mode '
        'native=$_nativeEnabled interstitial=$_interstitialEnabled '
        'rewarded=$_rewardedEnabled banners=$_bannersEnabled '
        'adFree=${AdFreeManager.instance.isAdFree} '
        'consent=${ConsentManager.instance.status.name} '
        'interstitialsShown=${frequency.shownThisSession}';
  }

  /// MREC (300x250) is allowed in every major in-feed/player placement.
  bool canShowMREC(MRECPlacement placement) {
    if (!adsAvailable || !_bannersEnabled) return false;
    return true;
  }
}

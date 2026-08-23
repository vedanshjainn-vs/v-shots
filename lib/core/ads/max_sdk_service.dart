// ═════════════════════════════════════════════════════════════════════════
// V Shots — VShotsMax (AppLovin MAX service)
//
// Architecture (Phase 2/8 — single coherent production path):
//
//   UI → VShotsAds (policy + frequency) → VShotsMax (this)
//        → AppLovin MAX SDK → mediated demand (AppLovin, Google/AdMob, ...)
//
// Rules implemented here:
//   • MAX SDK initializes ONCE at app startup (non-blocking; the plugin
//     itself enforces single init).
//   • Consent is applied BEFORE any ad request: the UMP decision is pushed
//     into MAX via setHasUserConsent, and the Google network inside MAX
//     reads GMA's UMP state directly (existing UMP system is REUSED, not
//     duplicated — Phase 9).
//   • Diagnostics report HONEST states (Phase 10): never "ready" when the
//     SDK is not initialized, config is missing, or consent is pending.
//   • Preload interstitial + rewarded when policy allows; re-preload after
//     show/failure. Native + banner views load on mount (platform views).
//   • Debug builds: verbose logging + creative/mediation debugger enabled.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:applovin_max/applovin_max.dart' as max;
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show ConsentStatus;

import 'ad_analytics.dart';
import 'ad_free_manager.dart';
import 'ad_state.dart';
import 'consent_manager.dart';
import 'max_config.dart';
import '../remote_config/remote_feature_flags.dart';

/// One in-flight rewarded session (routes the global MAX rewarded events to
/// the caller that started the show — user-initiated, always).
class RewardSession {
  RewardSession({
    required this.onGrant,
    required this.onClosed,
  });

  bool granted = false;
  final void Function() onGrant;
  final void Function(bool wasEarned) onClosed;
}

class VShotsMax {
  VShotsMax._();

  static final VShotsMax instance = VShotsMax._();

  bool _initStarted = false;
  bool _initSucceeded = false;
  String? _initError;
  final Completer<void> _ready = Completer<void>();

  bool get initStarted => _initStarted;
  bool get initSucceeded => _initSucceeded;
  String? get initError => _initError;

  /// Whether the MAX session reports test mode (test devices / test config).
  bool? sdkTestMode;

  // ── Per-format ready flags + last errors (honest diagnostics) ──────────
  bool interstitialReady = false;
  bool rewardedReady = false;
  final Map<String, String> formatErrors = {};

  // ── Event hooks for VShotsAds bounded on-demand loads ──────────────────
  VoidCallback? onInterstitialLoaded;
  VoidCallback? onRewardedLoaded;

  /// The active rewarded session (set by VShotsAds.showRewarded).
  RewardSession? rewardSession;

  /// One-time, non-blocking initialization (fire-and-forget from main).
  Future<void> initialize() async {
    if (_initStarted) return;
    _initStarted = true;
    if (!MaxConfig.isConfigured) {
      // Nothing to initialize — honest CONFIG_NOT_SET state in diagnostics.
      _completeReady();
      return;
    }
    // Phase 9: consent BEFORE any ad request.
    syncConsent();
    if (MaxConfig.debugBuild) {
      try {
        max.AppLovinMAX.setVerboseLogging(true);
        max.AppLovinMAX.setCreativeDebuggerEnabled(true);
      } catch (e) {
        debugPrint('[VShotsMax] debug tools error: $e');
      }
    }
    try {
      final config = await max.AppLovinMAX.initialize(MaxConfig.sdkKey!);
      _initSucceeded = config != null;
      sdkTestMode = config?.isTestModeEnabled;
      AdAnalytics.log(
        'max_sdk_initialized',
        detail: sdkTestMode == true ? 'test mode' : 'live mode',
      );
      if (kDebugMode) {
        debugPrint('[Ads] MAX initialized '
            '(testMode=$sdkTestMode, geo=${config?.consentFlowUserGeography})');
      }
    } catch (e) {
      _initError = e.toString();
      AdAnalytics.log('ad_load_failed', detail: 'MAX.initialize: $e');
    }
    _registerListeners();
    _completeReady();
    _preloadIfAllowed();
  }

  void _completeReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Bounded wait for SDK readiness. Never throws, never blocks startup.
  Future<void> waitReady({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      await _ready.future.timeout(timeout);
    } catch (_) {
      // fall through — caller checks initSucceeded / systemState
    }
  }

  /// Pushes the current UMP consent decision into MAX (personalized-ads
  /// flag). Called at init and on every consent status change. The Google
  /// network inside MAX additionally reads GMA's UMP state directly.
  void syncConsent() {
    if (!MaxConfig.isConfigured) return;
    try {
      max.AppLovinMAX.setHasUserConsent(
        ConsentManager.instance.canRequestPersonalizedAds,
      );
    } catch (e) {
      debugPrint('[VShotsMax] consent sync error: $e');
    }
  }

  /// Honest system state (Phase 10). Used by the diagnostics panel.
  AdSystemState systemState() {
    if (!RemoteFeatureFlags.instance.value('enable_ads', defaultValue: true)) {
      return AdSystemState.disabled;
    }
    if (!MaxConfig.isConfigured) return AdSystemState.maxNotConfigured;
    if (AdFreeManager.instance.isAdFree) return AdSystemState.adFree;
    if (ConsentManager.instance.status == ConsentStatus.required) {
      return AdSystemState.consentPending;
    }
    if (!_initStarted) return AdSystemState.maxInitializing;
    if (_initError != null) return AdSystemState.maxNotReady;
    if (!_initSucceeded) return AdSystemState.maxInitializing;
    return AdSystemState.ready;
  }

  bool _canPreload() => MaxConfig.isConfigured && _initSucceeded && _policyOpen;

  bool get _policyOpen =>
      RemoteFeatureFlags.instance.value('enable_ads', defaultValue: true) &&
      !AdFreeManager.instance.isAdFree &&
      ConsentManager.instance.status != ConsentStatus.required;

  /// Preloads interstitial + rewarded when allowed (cache for instant show).
  void _preloadIfAllowed() {
    if (!_canPreload()) return;
    if (!interstitialReady) {
      final unitId = MaxConfig.unitIdFor(MaxPlacement.interstitialSessionBreak);
      if (unitId != null) max.AppLovinMAX.loadInterstitial(unitId);
    }
    if (!rewardedReady) {
      final unitId = MaxConfig.unitIdFor(MaxPlacement.rewardedFeature);
      if (unitId != null) max.AppLovinMAX.loadRewardedAd(unitId);
    }
  }

  void _registerListeners() {
    // ── Interstitial ──────────────────────────────────────────────────
    max.AppLovinMAX.setInterstitialListener(max.InterstitialListener(
      onAdLoadedCallback: (ad) {
        interstitialReady = true;
        formatErrors.remove('interstitial');
        AdAnalytics.log('ad_loaded', placement: 'interstitial');
        onInterstitialLoaded?.call();
      },
      onAdLoadFailedCallback: (unitId, error) {
        interstitialReady = false;
        formatErrors['interstitial'] = '${error.code.name}: ${error.message}';
        AdAnalytics.log('ad_load_failed',
            placement: 'interstitial',
            detail: '${error.code.name}: ${error.message}');
        onInterstitialLoaded?.call();
      },
      onAdDisplayedCallback: (ad) =>
          AdAnalytics.log('ad_impression', placement: 'interstitial'),
      onAdDisplayFailedCallback: (ad, error) {
        interstitialReady = false;
        formatErrors['interstitial'] =
            'display ${error.code.name}: ${error.message}';
        AdAnalytics.log('ad_load_failed',
            placement: 'interstitial',
            detail: 'display: ${error.code.name}: ${error.message}');
      },
      onAdClickedCallback: (ad) {},
      onAdHiddenCallback: (ad) {
        AdAnalytics.log('ad_closed', placement: 'interstitial');
        interstitialReady = false;
        _preloadIfAllowed();
      },
    ));

    // ── Rewarded (user-initiated; reward only on SDK confirmation) ────
    max.AppLovinMAX.setRewardedAdListener(max.RewardedAdListener(
      onAdLoadedCallback: (ad) {
        rewardedReady = true;
        formatErrors.remove('rewarded');
        AdAnalytics.log('ad_loaded', placement: 'rewarded');
        onRewardedLoaded?.call();
      },
      onAdLoadFailedCallback: (unitId, error) {
        rewardedReady = false;
        formatErrors['rewarded'] = '${error.code.name}: ${error.message}';
        AdAnalytics.log('ad_load_failed',
            placement: 'rewarded',
            detail: '${error.code.name}: ${error.message}');
        onRewardedLoaded?.call();
      },
      onAdDisplayedCallback: (ad) {},
      onAdDisplayFailedCallback: (ad, error) {
        rewardedReady = false;
        formatErrors['rewarded'] =
            'display ${error.code.name}: ${error.message}';
        AdAnalytics.log('ad_load_failed',
            placement: 'rewarded',
            detail: 'display: ${error.code.name}: ${error.message}');
      },
      onAdClickedCallback: (ad) {},
      onAdReceivedRewardCallback: (ad, reward) {
        final session = rewardSession;
        if (session != null) {
          session.granted = true;
          AdAnalytics.log('rewarded_completed',
              detail: 'amount=${reward.amount} label=${reward.label}');
          session.onGrant();
        }
      },
      onAdHiddenCallback: (ad) {
        AdAnalytics.log('ad_closed', placement: 'rewarded');
        rewardedReady = false;
        final session = rewardSession;
        rewardSession = null;
        session?.onClosed(session.granted);
        _preloadIfAllowed();
      },
    ));

    // ── Widget AdViews (in-flow banner / MREC via MaxAdView) ───────────
    max.AppLovinMAX.setWidgetAdViewAdListener(max.WidgetAdViewAdListener(
      onAdLoadedCallback: (ad) => AdAnalytics.log('ad_loaded',
          placement: _placementForUnit(ad.adUnitId) ?? 'widget_ad_view'),
      onAdLoadFailedCallback: (unitId, error) {
        formatErrors[_placementForUnit(unitId) ?? 'widget_ad_view'] =
            '${error.code.name}: ${error.message}';
        AdAnalytics.log('ad_load_failed',
            placement: _placementForUnit(unitId) ?? 'widget_ad_view',
            detail: '${error.code.name}: ${error.message}');
      },
    ));
  }

  /// Reverse lookup: MAX unit ID → stable placement name (analytics only).
  String? _placementForUnit(String unitId) {
    for (final entry in MaxConfig.unitEnvKeys.entries) {
      if (MaxConfig.unitIdFor(entry.key) == unitId) return entry.key;
    }
    return null;
  }
}

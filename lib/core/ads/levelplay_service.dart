// ═════════════════════════════════════════════════════════════════════════
// V Shots — VShotsLevelPlay (Unity LevelPlay service)
//
// Architecture (single coherent production path):
//   UI → VShotsAds (policy + frequency) → VShotsLevelPlay (this)
//        → Unity LevelPlay → mediated demand (ironSource + approved networks)
//
// Rules implemented here:
//   • LevelPlay initializes ONCE at app startup (non-blocking; the plugin
//     enforces single init). Ads are loaded only after onInitSuccess.
//   • Consent (Phase 20): the existing UMP system is the single consent
//     source; its decision is pushed to LevelPlay (GDPR flag) BEFORE any
//     ad request, and re-pushed on every status change.
//   • Honest states for diagnostics: CONFIG_NOT_SET / SDK_INITIALIZING /
//     SDK_NOT_READY / CONSENT_REQUIRED / AD_FREE / DISABLED / READY.
//   • Impression-level revenue (Phase 27): every displayed ad + the SDK's
//     impression-data events are logged via AdAnalytics (network, revenue,
//     placement, format) for later network comparison.
//   • Debug builds: adapters debug + integration validation + test suite
//     metadata + TEST actions (development-only).
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show ConsentStatus;
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import 'ad_analytics.dart';
import 'ad_free_manager.dart';
import 'ad_state.dart';
import 'consent_manager.dart';
import 'levelplay_config.dart';
import '../remote_config/remote_feature_flags.dart';

/// One in-flight rewarded session (routes the global LevelPlay rewarded
/// events to the caller that started the show).
class RewardSession {
  RewardSession({
    required this.onGrant,
    required this.onClosed,
  });

  bool granted = false;
  final void Function() onGrant;
  final void Function(bool wasEarned) onClosed;
}

class VShotsLevelPlay {
  VShotsLevelPlay._();

  static final VShotsLevelPlay instance = VShotsLevelPlay._();

  // ── Init state ─────────────────────────────────────────────────────────
  bool _initStarted = false;
  bool _initSucceeded = false;
  String? _initError;
  final Completer<void> _ready = Completer<void>();

  /// Fired when init settles (success OR failure). Widgets that can only
  /// create ads after init listen to this — no timers, test-safe.
  final ValueNotifier<bool> readyNotifier = ValueNotifier<bool>(false);

  bool get initStarted => _initStarted;
  bool get initSucceeded => _initSucceeded;
  String? get initError => _initError;

  // ── Ad objects (created after successful init) ─────────────────────────
  LevelPlayInterstitialAd? _interstitialAd;
  LevelPlayRewardedAd? _rewardedAd;
  bool interstitialReady = false;
  bool rewardedReady = false;
  final Map<String, String> formatErrors = {};

  /// Per-format activity trail for the diagnostics panel:
  /// requested → loaded → shown / failed, with timestamps.
  final Map<String, DateTime> lastActivityAt = {};
  final Map<String, String> lastActivity = {};

  /// The network that ACTUALLY filled the last load per format
  /// (e.g. 'meta', 'unityAds') — surfaced in the diagnostics panel so the
  /// owner can see WHO filled, not just that LevelPlay requested.
  final Map<String, String> lastFillNetwork = {};

  /// Records which network filled [format] (called from every ad listener).
  void noteFill(String format, String? network) {
    if (network == null || network.isEmpty) return;
    lastFillNetwork[format] = network;
  }

  void noteActivity(String format, String activity) {
    lastActivityAt[format] = DateTime.now();
    lastActivity[format] = activity;
  }

  String activityLine(String format) {
    final at = lastActivityAt[format];
    final what = lastActivity[format];
    if (at == null || what == null) return 'no activity yet';
    final t = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)} — $what';
  }

  /// The active rewarded session (set by VShotsAds.showRewarded).
  RewardSession? rewardSession;

  /// Bounded wait for SDK readiness (never throws, never blocks startup).
  Future<void> waitReady({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      await _ready.future.timeout(timeout);
    } catch (_) {
      // fall through — caller checks initSucceeded / systemState
    }
  }

  // ── One-time init (fire-and-forget from main) ──────────────────────────
  Future<void> initialize() async {
    if (_initStarted) return;
    _initStarted = true;
    if (!LevelPlayConfig.isConfigured) {
      _completeReady(); // honest CONFIG_NOT_SET state
      return;
    }
    // Phase 20: consent BEFORE any ad request (existing UMP is the source).
    syncConsent();
    if (LevelPlayConfig.debugBuild) {
      try {
        // Official integration verification (debug only): adapter debug
        // logs + the LevelPlay integration test suite.
        await LevelPlay.setMetaData(
          {
            'is_test_suite': ['enable'],
            'is_adapters_debug': ['enable']
          },
        );
        await LevelPlay.setAdaptersDebug(true);
      } catch (e) {
        debugPrint('[VShotsLevelPlay] debug tools error: $e');
      }
    }
    try {
      final request =
          LevelPlayInitRequest.builder(LevelPlayConfig.appKey!).build();
      await LevelPlay.init(
        initRequest: request,
        initListener: _InitListener(this),
      );
    } catch (e) {
      _initError = e.toString();
      AdAnalytics.log('ad_load_failed', detail: 'LevelPlay.init: $e');
    }
    _completeReady();
    if (_initSucceeded) _preloadIfAllowed();
  }

  void _completeReady() {
    if (!_ready.isCompleted) {
      _ready.complete();
      readyNotifier.value = true;
    }
  }

  void _onInitSuccess(LevelPlayConfiguration configuration) {
    _initSucceeded = true;
    AdAnalytics.log(
      'levelplay_initialized',
      detail: configuration.toString(),
    );
    if (kDebugMode) {
      // Launch the official integration test suite for on-device
      // verification (debug builds only).
      unawaited(LevelPlay.launchTestSuite().catchError((_) {}));
    }
    _createAdObjects();
    // Register impression-level revenue analytics only once the SDK is
    // actually up (the plugin's addImpressionDataListener fires an
    // unawaited platform channel call — must not run in test envs where
    // the plugin channel is absent).
    LevelPlay.addImpressionDataListener(_ImpressionDataListener());
  }

  void _onInitFailed(LevelPlayInitError error) {
    _initError = error.toString();
    AdAnalytics.log('ad_load_failed', detail: 'LevelPlay init failed: $error');
  }

  void _createAdObjects() {
    final interUnit =
        LevelPlayConfig.unitIdFor(LevelPlayPlacement.interstitialSessionBreak);
    if (interUnit != null && _interstitialAd == null) {
      _interstitialAd = LevelPlayInterstitialAd(adUnitId: interUnit);
      _interstitialAd!.setListener(_InterstitialListener(this));
      _preloadIfAllowed();
    }
    final rewUnit =
        LevelPlayConfig.unitIdFor(LevelPlayPlacement.rewardedFeature);
    if (rewUnit != null && _rewardedAd == null) {
      _rewardedAd = LevelPlayRewardedAd(adUnitId: rewUnit);
      _rewardedAd!.setListener(_RewardedListener(this));
      _preloadIfAllowed();
    }
  }

  bool get _policyOpen =>
      RemoteFeatureFlags.instance.value('enable_ads', defaultValue: true) &&
      !AdFreeManager.instance.isAdFree &&
      ConsentManager.instance.status != ConsentStatus.required;

  /// Preloads interstitial + rewarded when policy allows (instant show).
  void _preloadIfAllowed() {
    if (!_initSucceeded || !_policyOpen) return;
    if (!interstitialReady) {
      noteActivity('interstitial', 'requested (preload)');
      AdAnalytics.log('ad_request', placement: 'interstitial');
      _interstitialAd?.loadAd();
    }
    if (!rewardedReady) {
      noteActivity('rewarded', 'requested (preload)');
      AdAnalytics.log('ad_request', placement: 'rewarded');
      _rewardedAd?.loadAd();
    }
  }

  /// Pushes the current UMP consent decision into LevelPlay (GDPR flag).
  /// Called at init and on every UMP status change.
  void syncConsent() {
    if (!LevelPlayConfig.isConfigured) return;
    try {
      // Global GDPR consent flag (the per-network API requires knowing the
      // dashboard's network list; the global flag covers all networks).
      // ignore: deprecated_member_use
      LevelPlay.setConsent(ConsentManager.instance.canRequestPersonalizedAds);
    } catch (e) {
      debugPrint('[VShotsLevelPlay] consent sync error: $e');
    }
  }

  // ── Honest system state (Phase 21) ────────────────────────────────────
  AdSystemState systemState() {
    if (!RemoteFeatureFlags.instance.value('enable_ads', defaultValue: true)) {
      return AdSystemState.disabled;
    }
    if (!LevelPlayConfig.isConfigured) return AdSystemState.maxNotConfigured;
    if (AdFreeManager.instance.isAdFree) return AdSystemState.adFree;
    if (ConsentManager.instance.status == ConsentStatus.required) {
      return AdSystemState.consentPending;
    }
    if (!_initStarted) return AdSystemState.maxInitializing;
    if (_initError != null) return AdSystemState.maxNotReady;
    if (!_initSucceeded) return AdSystemState.maxInitializing;
    return AdSystemState.ready;
  }

  // ── Development-only test actions (Phase 23) ───────────────────────────
  // Called ONLY from the debug-only diagnostics panel. They bypass the
  // production frequency policy on purpose and never affect the production
  // rules themselves.

  Future<String> testInterstitial() async {
    if (!LevelPlayConfig.isConfigured) {
      return 'FAILED — no LevelPlay app key in this build. Set the '
          'LEVELPLAY_APP_KEY secret and rebuild.';
    }
    if (!initSucceeded) {
      return 'FAILED — LevelPlay not initialized'
          '${initError != null ? ': $initError' : ''}';
    }
    final ad = _interstitialAd;
    final unitId =
        LevelPlayConfig.unitIdFor(LevelPlayPlacement.interstitialSessionBreak);
    if (ad == null || unitId == null) {
      return 'FAILED — INTERSTITIAL_SESSION_BREAK_01 unit missing.';
    }
    noteActivity('interstitial', 'requested (test button)');
    AdAnalytics.log('ad_request', placement: 'interstitial_test');
    if (await ad.isAdReady()) {
      noteActivity('interstitial', 'loaded → showing (test button)');
      await ad.showAd(placementName: 'INTERSTITIAL_TEST');
      return 'LOADED — interstitial is showing now (test ad).';
    }
    final loaded = Completer<void>();
    final prev = interstitialLoadedHook;
    interstitialLoadedHook = () {
      if (!loaded.isCompleted) loaded.complete();
    };
    unawaited(ad.loadAd());
    try {
      await loaded.future.timeout(const Duration(seconds: 30));
    } catch (_) {
      // timeout — report below
    }
    interstitialLoadedHook = prev;
    if (await ad.isAdReady()) {
      noteActivity('interstitial', 'loaded → showing (test button)');
      await ad.showAd(placementName: 'INTERSTITIAL_TEST');
      return 'LOADED — interstitial is showing now (test ad).';
    }
    final err = formatErrors['interstitial'];
    return 'FAILED to load (30 s): ${err ?? 'no fill — check the LevelPlay '
        'dashboard: is the unit created & active? is this device a '
        'registered TEST DEVICE? are networks enabled on the unit?'}';
  }

  Future<String> testRewarded() async {
    if (!LevelPlayConfig.isConfigured) {
      return 'FAILED — no LevelPlay app key in this build. Set the '
          'LEVELPLAY_APP_KEY secret and rebuild.';
    }
    if (!initSucceeded) {
      return 'FAILED — LevelPlay not initialized'
          '${initError != null ? ': $initError' : ''}';
    }
    final ad = _rewardedAd;
    final unitId =
        LevelPlayConfig.unitIdFor(LevelPlayPlacement.rewardedFeature);
    if (ad == null || unitId == null) {
      return 'FAILED — REWARDED_FEATURE_01 unit missing.';
    }
    noteActivity('rewarded', 'requested (test button)');
    AdAnalytics.log('rewarded_started', placement: 'rewarded_test');
    bool earned = false;
    final closed = Completer<void>();
    rewardSession = RewardSession(
      onGrant: () {
        earned = true;
        noteActivity('rewarded', 'REWARD CONFIRMED (test button)');
      },
      onClosed: (wasEarned) {
        if (!closed.isCompleted) closed.complete();
      },
    );
    if (!(await ad.isAdReady())) {
      final loaded = Completer<void>();
      final prev = rewardedLoadedHook;
      rewardedLoadedHook = () {
        if (!loaded.isCompleted) loaded.complete();
      };
      unawaited(ad.loadAd());
      try {
        await loaded.future.timeout(const Duration(seconds: 30));
      } catch (_) {
        // timeout
      }
      rewardedLoadedHook = prev;
      if (!(await ad.isAdReady())) {
        rewardSession = null;
        final err = formatErrors['rewarded'];
        return 'FAILED to load (30 s): ${err ?? 'no fill'}';
      }
    }
    await ad.showAd(placementName: 'REWARDED_TEST');
    try {
      await closed.future.timeout(const Duration(seconds: 180));
    } catch (_) {
      // timeout
    }
    rewardSession = null;
    return earned
        ? 'COMPLETED — reward callback fired (LevelPlay-confirmed) ✓'
        : 'closed without completion — no reward (correct behaviour)';
  }

  // ── Hooks (wired by the listeners below; used by VShotsAds for bounded
  // on-demand loads) ─────────────────────────────────────────────────────────
  VoidCallback? interstitialLoadedHook;
  VoidCallback? rewardedLoadedHook;

  /// Ad object accessors for the facade (null until created after init).
  LevelPlayInterstitialAd? peekInterstitial() => _interstitialAd;
  LevelPlayRewardedAd? peekRewarded() => _rewardedAd;
}

// ── Listeners (kept out of the service class for clarity) ────────────────

class _InitListener with LevelPlayInitListener {
  _InitListener(this.service);
  final VShotsLevelPlay service;

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) {
    service._onInitSuccess(configuration);
  }

  @override
  void onInitFailed(LevelPlayInitError error) => service._onInitFailed(error);
}

class _InterstitialListener with LevelPlayInterstitialAdListener {
  _InterstitialListener(this.service);
  final VShotsLevelPlay service;

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    service.interstitialReady = true;
    service.formatErrors.remove('interstitial');
    service.noteFill('interstitial', adInfo.adNetwork);
    service.noteActivity(
        'interstitial', 'LOADED (network: ${adInfo.adNetwork})');
    AdAnalytics.log('ad_loaded',
        placement: 'interstitial', detail: 'network=${adInfo.adNetwork}');
    service.interstitialLoadedHook?.call();
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    service.interstitialReady = false;
    final msg = '$error';
    service.formatErrors['interstitial'] = msg;
    service.noteActivity('interstitial', 'LOAD FAILED — $msg');
    AdAnalytics.log('ad_load_failed', placement: 'interstitial', detail: msg);
    service.interstitialLoadedHook?.call();
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    service.noteActivity(
        'interstitial', 'SHOWN (network: ${adInfo.adNetwork})');
    AdAnalytics.log('ad_displayed',
        placement: 'interstitial',
        detail: 'network=${adInfo.adNetwork} revenue=${adInfo.revenue}');
  }

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    service.interstitialReady = false;
    final msg = '$error';
    service.formatErrors['interstitial'] = 'display: $msg';
    service.noteActivity('interstitial', 'SHOW FAILED — $msg');
    AdAnalytics.log('ad_load_failed',
        placement: 'interstitial', detail: 'display: $msg');
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) =>
      service.noteActivity('interstitial', 'CLICKED');

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) {
    service.noteActivity('interstitial', 'closed');
    AdAnalytics.log('ad_closed', placement: 'interstitial');
    service.interstitialReady = false;
    service._preloadIfAllowed();
  }

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) =>
      service.noteActivity('interstitial', 'info updated');
}

class _RewardedListener with LevelPlayRewardedAdListener {
  _RewardedListener(this.service);
  final VShotsLevelPlay service;

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    service.rewardedReady = true;
    service.formatErrors.remove('rewarded');
    service.noteFill('rewarded', adInfo.adNetwork);
    service.noteActivity('rewarded', 'LOADED (network: ${adInfo.adNetwork})');
    AdAnalytics.log('ad_loaded', placement: 'rewarded');
    service.rewardedLoadedHook?.call();
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    service.rewardedReady = false;
    final msg = '$error';
    service.formatErrors['rewarded'] = msg;
    service.noteActivity('rewarded', 'LOAD FAILED — $msg');
    AdAnalytics.log('ad_load_failed', placement: 'rewarded', detail: msg);
    service.rewardedLoadedHook?.call();
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) =>
      service.noteActivity('rewarded', 'SHOWN (playing)');

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    service.rewardedReady = false;
    final msg = '$error';
    service.formatErrors['rewarded'] = 'display: $msg';
    service.noteActivity('rewarded', 'SHOW FAILED — $msg');
    AdAnalytics.log('ad_load_failed',
        placement: 'rewarded', detail: 'display: $msg');
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  /// Reward is granted ONLY here — the SDK-confirmed completion callback
  /// (Phase 15). Never on clicks, never before completion.
  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) {
    final session = service.rewardSession;
    if (session != null) {
      session.granted = true;
      AdAnalytics.log('rewarded_completed',
          detail:
              'amount=${reward.amount} name=${reward.name} network=${adInfo.adNetwork}');
      session.onGrant();
    }
  }

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) {
    service.noteActivity('rewarded', 'closed');
    AdAnalytics.log('ad_closed', placement: 'rewarded');
    service.rewardedReady = false;
    final session = service.rewardSession;
    service.rewardSession = null;
    session?.onClosed(session.granted);
    service._preloadIfAllowed();
  }

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) =>
      service.noteActivity('rewarded', 'info updated');
}

/// LevelPlay impression-data listener → centralized analytics (Phase 27):
/// impression-level revenue per network/format/placement for later
/// network comparison (ironSource vs Google vs Meta vs …).
class _ImpressionDataListener with LevelPlayImpressionDataListener {
  @override
  void onImpressionSuccess(LevelPlayImpressionData impressionData) {
    AdAnalytics.log(
      'ad_revenue',
      placement: impressionData.placement ?? impressionData.adFormat,
      detail:
          'network=${impressionData.adNetwork ?? '-'} format=${impressionData.adFormat ?? '-'} revenue=${impressionData.revenue ?? 0} precision=${impressionData.precision ?? '-'}',
    );
  }
}

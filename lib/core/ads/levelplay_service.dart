// ═════════════════════════════════════════════════════════════════════════
// V Shots — VShotsLevelPlay (Unity LevelPlay service)
//
// Architecture (single coherent production path):
//   UI → VShotsAds (policy + frequency) → VShotsLevelPlay (this)
//        → Unity LevelPlay → mediated demand (ironSource + approved networks)
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

class RewardSession {
  RewardSession({required this.onGrant, required this.onClosed});

  bool granted = false;
  final void Function() onGrant;
  final void Function(bool wasEarned) onClosed;
}

class VShotsLevelPlay {
  VShotsLevelPlay._();

  static final VShotsLevelPlay instance = VShotsLevelPlay._();

  bool _initStarted = false;
  bool _initSucceeded = false;
  String? _initError;
  final Completer<void> _ready = Completer<void>();
  final ValueNotifier<bool> readyNotifier = ValueNotifier<bool>(false);

  bool get initStarted => _initStarted;
  bool get initSucceeded => _initSucceeded;
  String? get initError => _initError;

  LevelPlayInterstitialAd? _interstitialAd;
  LevelPlayRewardedAd? _rewardedAd;
  bool interstitialReady = false;
  bool rewardedReady = false;
  bool _interstitialLoadInFlight = false;
  bool _rewardedLoadInFlight = false;
  final Map<String, String> formatErrors = {};
  final Map<String, DateTime> lastActivityAt = {};
  final Map<String, String> lastActivity = {};
  final Map<String, String> lastFillNetwork = {};

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

  RewardSession? rewardSession;

  Future<void> waitReady({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      await _ready.future.timeout(timeout);
    } catch (_) {}
  }

  Future<void> initialize() async {
    if (_initStarted) return;
    _initStarted = true;
    if (!LevelPlayConfig.isConfigured) {
      _completeReady();
      return;
    }
    syncConsent();
    if (LevelPlayConfig.debugBuild) {
      try {
        await LevelPlay.setMetaData({
          'is_test_suite': ['enable'],
          'is_adapters_debug': ['enable'],
        });
        await LevelPlay.setAdaptersDebug(true);
      } catch (e) {
        debugPrint('[VShotsLevelPlay] debug tools error: $e');
      }
    }
    try {
      final request = LevelPlayInitRequest.builder(
        LevelPlayConfig.appKey!,
      ).build();
      await LevelPlay.init(
        initRequest: request,
        initListener: _InitListener(this),
      );
    } catch (e) {
      _initError = e.toString();
      AdAnalytics.log('ad_load_failed', detail: 'LevelPlay.init: $e');
      _completeReady();
    }
  }

  void _completeReady() {
    if (!_ready.isCompleted) {
      _ready.complete();
      readyNotifier.value = true;
    }
  }

  void _onInitSuccess(LevelPlayConfiguration configuration) {
    _initSucceeded = true;
    AdAnalytics.log('levelplay_initialized', detail: configuration.toString());
    _createAdObjects();
    _completeReady();
    LevelPlay.addImpressionDataListener(_ImpressionDataListener());
  }

  void _onInitFailed(LevelPlayInitError error) {
    _initError = error.toString();
    AdAnalytics.log('ad_load_failed', detail: 'LevelPlay init failed: $error');
    _completeReady();
  }

  void _createAdObjects() {
    final interUnit = LevelPlayConfig.unitIdFor(
      LevelPlayPlacement.interstitialSessionBreak,
    );
    if (interUnit != null && _interstitialAd == null) {
      _interstitialAd = LevelPlayInterstitialAd(adUnitId: interUnit);
      _interstitialAd!.setListener(_InterstitialListener(this));
    }

    final rewUnit = LevelPlayConfig.unitIdFor(
      LevelPlayPlacement.rewardedFeature,
    );
    if (rewUnit != null && _rewardedAd == null) {
      _rewardedAd = LevelPlayRewardedAd(adUnitId: rewUnit);
      _rewardedAd!.setListener(_RewardedListener(this));
    }

    // Create both objects first, then issue exactly one preload pass. The
    // previous ordering could call _preloadIfAllowed twice and send duplicate
    // requests for the same newly-created rewarded/interstitial objects.
    _preloadIfAllowed();
  }

  bool get _policyOpen =>
      RemoteFeatureFlags.instance.value('enable_ads', defaultValue: true) &&
      !AdFreeManager.instance.isAdFree &&
      ConsentManager.instance.status != ConsentStatus.required;

  void _preloadIfAllowed() {
    if (!_initSucceeded || !_policyOpen) return;
    requestInterstitialLoad();
    requestRewardedLoad();
  }

  void requestInterstitialLoad() {
    if (!_initSucceeded || !_policyOpen || interstitialReady) return;
    final ad = _interstitialAd;
    if (ad == null || _interstitialLoadInFlight) return;
    _interstitialLoadInFlight = true;
    noteActivity('interstitial', 'requested (preload)');
    AdAnalytics.log('ad_request', placement: 'interstitial');
    unawaited(ad.loadAd());
  }

  void requestRewardedLoad() {
    if (!_initSucceeded || !_policyOpen || rewardedReady) return;
    final ad = _rewardedAd;
    if (ad == null || _rewardedLoadInFlight) return;
    _rewardedLoadInFlight = true;
    noteActivity('rewarded', 'requested (preload)');
    AdAnalytics.log('ad_request', placement: 'rewarded');
    unawaited(ad.loadAd());
  }

  void syncConsent() {
    if (!LevelPlayConfig.isConfigured) return;
    try {
      // ignore: deprecated_member_use
      LevelPlay.setConsent(ConsentManager.instance.canRequestPersonalizedAds);
    } catch (e) {
      debugPrint('[VShotsLevelPlay] consent sync error: $e');
    }
  }

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
    final unitId = LevelPlayConfig.unitIdFor(
      LevelPlayPlacement.interstitialSessionBreak,
    );
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
    requestInterstitialLoad();
    try {
      await loaded.future.timeout(const Duration(seconds: 30));
    } catch (_) {}
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
    final unitId = LevelPlayConfig.unitIdFor(
      LevelPlayPlacement.rewardedFeature,
    );
    if (ad == null || unitId == null) {
      return 'FAILED — REWARDED_FEATURE_01 unit missing.';
    }
    noteActivity('rewarded', 'requested (test button)');
    AdAnalytics.log('rewarded_started', placement: 'rewarded_test');

    var ready = await ad.isAdReady();
    if (!ready) {
      final loaded = Completer<void>();
      final prev = rewardedLoadedHook;
      rewardedLoadedHook = () {
        if (!loaded.isCompleted) loaded.complete();
      };
      requestRewardedLoad();
      try {
        await loaded.future.timeout(const Duration(seconds: 30));
      } catch (_) {} finally {
        rewardedLoadedHook = prev;
      }
      ready = await ad.isAdReady();
      if (!ready) {
        final err = formatErrors['rewarded'];
        return 'FAILED to load (30 s): ${err ?? 'no fill'}';
      }
    }

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

    try {
      await ad.showAd();
    } catch (e) {
      rewardSession = null;
      noteActivity('rewarded', 'SHOW FAILED — $e');
      return 'FAILED to show: $e';
    }

    try {
      await closed.future.timeout(const Duration(seconds: 180));
    } catch (_) {
      rewardSession = null;
      return 'FAILED — session timed out waiting for ad completion (180 s)';
    }
    rewardSession = null;
    return earned
        ? 'COMPLETED — reward callback fired (LevelPlay-confirmed) ✓'
        : 'closed without completion — no reward (correct behaviour)';
  }

  VoidCallback? interstitialLoadedHook;
  VoidCallback? interstitialClosedHook;
  VoidCallback? rewardedLoadedHook;

  LevelPlayInterstitialAd? peekInterstitial() => _interstitialAd;
  LevelPlayRewardedAd? peekRewarded() => _rewardedAd;
}

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
    service._interstitialLoadInFlight = false;
    service.interstitialReady = true;
    service.formatErrors.remove('interstitial');
    service.noteFill('interstitial', adInfo.adNetwork);
    service.noteActivity(
      'interstitial',
      'LOADED (network: ${adInfo.adNetwork})',
    );
    AdAnalytics.log(
      'ad_loaded',
      placement: 'interstitial',
      detail: 'network=${adInfo.adNetwork}',
    );
    service.interstitialLoadedHook?.call();
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    service._interstitialLoadInFlight = false;
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
      'interstitial',
      'SHOWN (network: ${adInfo.adNetwork})',
    );
    AdAnalytics.log(
      'ad_displayed',
      placement: 'interstitial',
      detail: 'network=${adInfo.adNetwork} revenue=${adInfo.revenue}',
    );
  }

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    service.interstitialReady = false;
    final msg = '$error';
    service.formatErrors['interstitial'] = 'display: $msg';
    service.noteActivity('interstitial', 'SHOW FAILED — $msg');
    AdAnalytics.log(
      'ad_load_failed',
      placement: 'interstitial',
      detail: 'display: $msg',
    );
    service.interstitialClosedHook?.call();
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) =>
      service.noteActivity('interstitial', 'CLICKED');

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) {
    service.noteActivity('interstitial', 'closed');
    AdAnalytics.log('ad_closed', placement: 'interstitial');
    service.interstitialReady = false;
    service.interstitialClosedHook?.call();
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
    service._rewardedLoadInFlight = false;
    service.rewardedReady = true;
    service.formatErrors.remove('rewarded');
    service.noteFill('rewarded', adInfo.adNetwork);
    service.noteActivity('rewarded', 'LOADED (network: ${adInfo.adNetwork})');
    AdAnalytics.log('ad_loaded', placement: 'rewarded');
    service.rewardedLoadedHook?.call();
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    service._rewardedLoadInFlight = false;
    service.rewardedReady = false;
    final msg = '$error';
    service.formatErrors['rewarded'] = msg;
    service.noteActivity('rewarded', 'LOAD FAILED — $msg');
    AdAnalytics.log('ad_load_failed', placement: 'rewarded', detail: msg);
    service.rewardedLoadedHook?.call();
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    service.rewardedReady = false;
    service.noteActivity('rewarded', 'SHOWN (playing)');
  }

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    service.rewardedReady = false;
    service._rewardedLoadInFlight = false;
    final msg = '$error';
    service.formatErrors['rewarded'] = 'display: $msg';
    service.noteActivity('rewarded', 'SHOW FAILED — $msg');
    AdAnalytics.log(
      'ad_load_failed',
      placement: 'rewarded',
      detail: 'display: $msg',
    );
    final session = service.rewardSession;
    service.rewardSession = null;
    session?.onClosed(false);
    service._preloadIfAllowed();
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) {
    final session = service.rewardSession;
    if (session != null) {
      session.granted = true;
      AdAnalytics.log(
        'rewarded_completed',
        detail: 'amount=${reward.amount} name=${reward.name} '
            'network=${adInfo.adNetwork}',
      );
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

class _ImpressionDataListener with LevelPlayImpressionDataListener {
  @override
  void onImpressionSuccess(LevelPlayImpressionData impressionData) {
    AdAnalytics.log(
      'ad_revenue',
      placement: impressionData.placement ?? impressionData.adFormat,
      detail: 'network=${impressionData.adNetwork ?? '-'} '
          'format=${impressionData.adFormat ?? '-'} '
          'revenue=${impressionData.revenue ?? 0} '
          'precision=${impressionData.precision ?? '-'}',
    );
  }
}

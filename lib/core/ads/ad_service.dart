// ═════════════════════════════════════════════════════════════════════════
// V Shots — VShotsAds (central ad service / facade)
//
// UI → VShotsAds → (policy, frequency, consent) → google_mobile_ads → AdMob
//
// Screens/widgets talk ONLY to this service (and to the self-contained
// NativeAdWidget / AdBannerWidget which are policy-gated internally).
//
// Guarantees (fail-safe, per spec):
//   - no fill / SDK error / timeout / not-ready  ⇒  normal app behavior
//   - no ad is ever shown when AdPolicy denies it
//   - rewarded ads are USER-INITIATED ONLY; the reward is granted only when
//     the SDK confirms completion (onUserEarnedReward)
//   - every SDK interaction is wrapped — an ad bug can never crash the app
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_analytics.dart';
import 'ad_config.dart';
import 'ad_manager.dart';
import 'ad_policy.dart';
import 'consent_manager.dart';

/// Result of a user-initiated rewarded ad session.
enum RewardOutcome { completed, canceled, failed }

class VShotsAds {
  VShotsAds._();

  static final VShotsAds instance = VShotsAds._();

  InterstitialAd? _readyInterstitial;
  Completer<void>? _interstitialLoad;

  /// Waits (bounded) for AdMob init to finish. Never throws.
  /// Returns true when the SDK is ready to serve ads.
  Future<bool> ensureReady({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      await AdManager.instance.waitForReady(timeout: timeout);
    } catch (_) {
      // fall through — caller checks isInitialized
    }
    return AdManager.instance.isInitialized;
  }

  /// Warm-up: called once from the shell after startup. Preloads the
  /// interstitial so a later tab-switch ad is instant. No-op unless allowed.
  Future<void> warmUp() async {
    final p = AdPolicy.instance;
    if (!p.adsAvailable || !p.interstitialEnabled) return;
    await ensureReady();
    _preloadInterstitial();
  }

  // ── Interstitials ───────────────────────────────────────────────────────

  /// Preloads one interstitial in the background (policy allows it, none
  /// ready, none in flight). Preload is NOT gated by the cooldown — an ad
  /// loaded now may be shown after the cooldown passes.
  void _preloadInterstitial() {
    final p = AdPolicy.instance;
    if (_readyInterstitial != null) return;
    if (_interstitialLoad != null) return; // already in flight
    if (!p.adsAvailable || !p.interstitialEnabled) return;

    final loadDone = Completer<void>();
    _interstitialLoad = loadDone;
    AdAnalytics.log('ad_request', placement: 'interstitial');
    unawaited(() async {
      try {
        await InterstitialAd.load(
          adUnitId: AdConfig.interstitialAdUnitId,
          request: ConsentManager.instance.buildAdRequest(),
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (ad) {
              AdAnalytics.log('ad_loaded', placement: 'interstitial');
              ad.fullScreenContentCallback =
                  FullScreenContentCallback<InterstitialAd>(
                onAdShowedFullScreenContent: (shown) {},
                onAdDismissedFullScreenContent: (ad) {
                  AdAnalytics.log('ad_closed', placement: 'interstitial');
                  ad.dispose();
                  _readyInterstitial = null;
                  _preloadInterstitial();
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  AdAnalytics.log('ad_load_failed',
                      placement: 'interstitial', detail: error.message);
                  ad.dispose();
                  _readyInterstitial = null;
                  _preloadInterstitial();
                },
              );
              _readyInterstitial = ad;
            },
            onAdFailedToLoad: (error) {
              AdAnalytics.log('ad_load_failed',
                  placement: 'interstitial', detail: error.message);
              _readyInterstitial = null;
            },
          ),
        );
      } catch (e) {
        AdAnalytics.log('ad_load_failed',
            placement: 'interstitial', detail: e.toString());
      } finally {
        _interstitialLoad = null;
        if (!loadDone.isCompleted) loadDone.complete();
      }
    }());
  }

  /// Shows an interstitial at a NATURAL transition (user-initiated tab
  /// switch). Policy + cooldown + caps are enforced here; if anything is not
  /// ready the app simply continues. Callers must NOT call this during
  /// playback or right after launch/login — the frequency controller's
  /// dwell guard also protects launch.
  Future<void> maybeShowInterstitial({required String trigger}) async {
    final p = AdPolicy.instance;
    if (!p.canShowInterstitial()) return;

    InterstitialAd? ad = _readyInterstitial;
    if (ad == null) {
      // Nothing ready: kick (or join) a bounded on-demand load.
      _preloadInterstitial();
      final loader = _interstitialLoad;
      if (loader != null) {
        try {
          await loader.future.timeout(const Duration(seconds: 2));
        } catch (_) {
          // timeout / error — proceed with whatever is ready
        }
        ad = _readyInterstitial;
      }
    }
    if (ad == null) return; // fail-safe: continue normal behavior

    _readyInterstitial = null;
    AdAnalytics.log('interstitial_shown', placement: trigger);
    p.frequency.recordShown();
    try {
      unawaited(ad.show());
    } catch (e) {
      // Presentation failure is also reported via the full-screen callback;
      // nothing else to do — the app continues normally.
      debugPrint('[VShotsAds] interstitial show error: $e');
    }
  }

  // ── Rewarded (user-initiated only) ──────────────────────────────────────

  /// Shows a rewarded ad. MUST be called from an explicit user action
  /// (there is no other path — no autoplay anywhere in this service).
  ///
  /// [onRewardGranted] is invoked ONLY when the SDK confirms the user earned
  /// the reward (onUserEarnedReward). Canceling or failing returns without
  /// granting anything.
  Future<RewardOutcome> showRewarded({
    required String purpose,
    FutureOr<void> Function()? onRewardGranted,
  }) async {
    if (!AdPolicy.instance.canShowRewarded()) {
      return RewardOutcome.failed;
    }
    if (!await ensureReady(timeout: const Duration(seconds: 6))) {
      return RewardOutcome.failed;
    }
    AdAnalytics.log('rewarded_started', placement: purpose);

    final loaded = Completer<RewardedAd>();
    final closed = Completer<void>();
    bool earned = false;

    try {
      AdAnalytics.log('ad_request', placement: purpose);
      await RewardedAd.load(
        adUnitId: AdConfig.rewardedAdUnitId,
        request: ConsentManager.instance.buildAdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            AdAnalytics.log('ad_loaded', placement: purpose);
            ad.fullScreenContentCallback =
                FullScreenContentCallback<RewardedAd>(
              onAdShowedFullScreenContent: (shown) {},
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (!closed.isCompleted) closed.complete();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                AdAnalytics.log('ad_load_failed',
                    placement: purpose, detail: error.message);
                ad.dispose();
                if (!closed.isCompleted) closed.complete();
              },
            );
            if (!loaded.isCompleted) loaded.complete(ad);
          },
          onAdFailedToLoad: (error) {
            AdAnalytics.log('ad_load_failed',
                placement: purpose, detail: error.message);
            if (!loaded.isCompleted) {
              loaded.completeError('rewarded load failed: ${error.message}');
            }
          },
        ),
      );

      final ad = await loaded.future.timeout(const Duration(seconds: 8));
      AdAnalytics.log('ad_request', placement: purpose, detail: 'presentation');
      await ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        earned = true;
        AdAnalytics.log('rewarded_completed', placement: purpose);
        try {
          onRewardGranted?.call();
        } catch (e) {
          debugPrint('[VShotsAds] reward grant error: $e');
        }
      });

      // Wait for the user to close the ad (bounded) and settle the outcome.
      try {
        await closed.future.timeout(const Duration(seconds: 180));
      } on TimeoutException {
        // Ad still open after the bound — settle what we know so far.
      }
      return earned ? RewardOutcome.completed : RewardOutcome.canceled;
    } on TimeoutException {
      return earned ? RewardOutcome.completed : RewardOutcome.failed;
    } catch (e) {
      AdAnalytics.log('ad_load_failed',
          placement: purpose, detail: e.toString());
      return earned ? RewardOutcome.completed : RewardOutcome.failed;
    }
  }
}

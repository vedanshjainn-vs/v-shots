// ═════════════════════════════════════════════════════════════════════════
// V Shots — VShotsAds (central ad facade, AppLovin MAX backed)
//
// UI → VShotsAds → VShotsMax → AppLovin MAX → mediated networks.
//
// Screens/widgets talk ONLY to this facade (and the self-contained
// NativeAdWidget / AdBannerWidget which are policy-gated internally).
//
// Guarantees (fail-safe, per spec):
//   - no fill / SDK error / timeout / not-ready / not-configured
//     ⇒ normal app behavior continues
//   - no ad is ever shown when AdPolicy denies it
//   - interstitials only at natural transitions, with the centralized
//     cooldown / session cap / dwell guard (AdPolicy.frequency)
//   - rewarded ads are USER-INITIATED ONLY; the reward is granted only
//     when the MAX SDK confirms completion (onAdReceivedReward)
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:applovin_max/applovin_max.dart' as max;
import 'package:flutter/foundation.dart';

import 'ad_analytics.dart';
import 'ad_policy.dart';
import 'max_config.dart';
import 'max_sdk_service.dart';

/// Result of a user-initiated rewarded ad session.
enum RewardOutcome { completed, canceled, failed }

class VShotsAds {
  VShotsAds._();

  static final VShotsAds instance = VShotsAds._();

  // ── Interstitial (natural transitions only) ───────────────────────────

  /// Shows an interstitial at a user-initiated transition (tab switch).
  /// Cooldown (180 s), session cap (4) and the 60 s dwell guard live
  /// centrally in AdPolicy. If anything is not ready, the app simply
  /// continues. Callers must NOT call this during playback.
  Future<void> maybeShowInterstitial({required String trigger}) async {
    final policy = AdPolicy.instance;
    if (!policy.canShowInterstitial()) return;
    final unitId = MaxConfig.unitIdFor(MaxPlacement.interstitialSessionBreak);
    if (unitId == null) return;

    await VShotsMax.instance.waitReady(timeout: const Duration(seconds: 2));
    if (!VShotsMax.instance.initSucceeded) return;

    var ready = await max.AppLovinMAX.isInterstitialReady(unitId) ?? false;
    if (!ready) {
      // Bounded on-demand load: request, wait for the listener event.
      final loaded = Completer<void>();
      VShotsMax.instance.onInterstitialLoaded = () {
        if (!loaded.isCompleted) loaded.complete();
      };
      try {
        max.AppLovinMAX.loadInterstitial(unitId);
        await loaded.future.timeout(const Duration(seconds: 3));
      } catch (_) {
        // timeout / error — proceed with whatever is ready
      } finally {
        VShotsMax.instance.onInterstitialLoaded = null;
      }
      ready = await max.AppLovinMAX.isInterstitialReady(unitId) ?? false;
    }
    if (!ready) return; // fail-safe: continue normal behavior

    policy.frequency.recordShown();
    AdAnalytics.log('interstitial_shown', placement: trigger);
    try {
      max.AppLovinMAX.showInterstitial(unitId, placement: trigger);
    } catch (e) {
      // Presentation failure is also reported via the listener; the app
      // continues normally.
      debugPrint('[VShotsAds] interstitial show error: $e');
    }
  }

  // ── Rewarded (user-initiated only) ────────────────────────────────────

  /// Shows a rewarded ad. MUST be called from an explicit user action
  /// (Settings → Rewards). The reward is granted ONLY when the MAX SDK
  /// confirms completion. Canceling or failing grants nothing.
  Future<RewardOutcome> showRewarded({
    required String purpose,
    FutureOr<void> Function()? onRewardGranted,
  }) async {
    if (!AdPolicy.instance.canShowRewarded()) {
      return RewardOutcome.failed;
    }
    final unitId = MaxConfig.unitIdFor(MaxPlacement.rewardedFeature);
    if (unitId == null) return RewardOutcome.failed;

    await VShotsMax.instance.waitReady(timeout: const Duration(seconds: 6));
    if (!VShotsMax.instance.initSucceeded) return RewardOutcome.failed;

    AdAnalytics.log('rewarded_started', placement: purpose);

    var ready = await max.AppLovinMAX.isRewardedAdReady(unitId) ?? false;
    if (!ready) {
      final loaded = Completer<void>();
      VShotsMax.instance.onRewardedLoaded = () {
        if (!loaded.isCompleted) loaded.complete();
      };
      try {
        max.AppLovinMAX.loadRewardedAd(unitId);
        await loaded.future.timeout(const Duration(seconds: 8));
      } catch (_) {
        // timeout / error — proceed with whatever is ready
      } finally {
        VShotsMax.instance.onRewardedLoaded = null;
      }
      ready = await max.AppLovinMAX.isRewardedAdReady(unitId) ?? false;
    }
    if (!ready) return RewardOutcome.failed;

    // Wire the session: reward granted ONLY on SDK-confirmed completion.
    bool granted = false;
    final result = Completer<RewardOutcome>();
    VShotsMax.instance.rewardSession = RewardSession(
      onGrant: () {
        granted = true;
        try {
          onRewardGranted?.call();
        } catch (e) {
          debugPrint('[VShotsAds] reward grant error: $e');
        }
      },
      onClosed: (wasEarned) {
        if (!result.isCompleted) {
          result.complete(
              wasEarned ? RewardOutcome.completed : RewardOutcome.canceled);
        }
      },
    );

    try {
      max.AppLovinMAX.showRewardedAd(unitId, placement: purpose);
    } catch (e) {
      VShotsMax.instance.rewardSession = null;
      AdAnalytics.log('ad_load_failed', placement: purpose, detail: 'show: $e');
      return RewardOutcome.failed;
    }

    try {
      return await result.future.timeout(const Duration(seconds: 180));
    } on TimeoutException {
      VShotsMax.instance.rewardSession = null;
      // Timed out before the close event: honor a confirmed reward,
      // otherwise fail safe.
      return granted ? RewardOutcome.completed : RewardOutcome.failed;
    }
  }
}

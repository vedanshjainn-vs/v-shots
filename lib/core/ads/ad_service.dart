// ═════════════════════════════════════════════════════════════════════════
// V Shots — VShotsAds (central ad facade, Unity LevelPlay backed)
//
// UI → VShotsAds → VShotsLevelPlay → Unity LevelPlay → mediated networks.
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
//     when the LevelPlay SDK confirms completion (onAdRewarded)
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ad_analytics.dart';
import 'ad_policy.dart';
import 'levelplay_config.dart';
import 'levelplay_service.dart';

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
    final unitId = LevelPlayConfig.unitIdFor(
      LevelPlayPlacement.interstitialSessionBreak,
    );
    if (unitId == null) return;

    await VShotsLevelPlay.instance.waitReady(
      timeout: const Duration(seconds: 2),
    );
    if (!VShotsLevelPlay.instance.initSucceeded) return;

    final ad = VShotsLevelPlay.instance.peekInterstitial();
    if (ad == null) return;

    var ready = await ad.isAdReady();
    if (!ready) {
      // Bounded on-demand load: request, wait for the listener event.
      final loaded = Completer<void>();
      final prev = VShotsLevelPlay.instance.interstitialLoadedHook;
      VShotsLevelPlay.instance.interstitialLoadedHook = () {
        if (!loaded.isCompleted) loaded.complete();
      };
      try {
        unawaited(ad.loadAd());
        await loaded.future.timeout(const Duration(seconds: 3));
      } catch (_) {
        // timeout / error — proceed with whatever is ready
      } finally {
        VShotsLevelPlay.instance.interstitialLoadedHook = prev;
      }
      ready = await ad.isAdReady();
    }
    if (!ready) return; // fail-safe: continue normal behavior

    policy.frequency.recordShown();
    AdAnalytics.log('interstitial_shown', placement: trigger);
    try {
      await ad.showAd(placementName: trigger);
    } catch (e) {
      // Presentation failure is also reported via the listener; the app
      // continues normally.
      debugPrint('[VShotsAds] interstitial show error: $e');
    }
  }

  // ── Rewarded (user-initiated only) ────────────────────────────────────

  /// Shows a rewarded ad. MUST be called from an explicit user action
  /// (Settings → Rewards). The reward is granted ONLY when the LevelPlay
  /// SDK confirms completion (onAdRewarded). Canceling or failing grants
  /// nothing.
  Future<RewardOutcome> showRewarded({
    required String purpose,
    FutureOr<void> Function()? onRewardGranted,
  }) async {
    if (!AdPolicy.instance.canShowRewarded()) {
      return RewardOutcome.failed;
    }
    final unitId = LevelPlayConfig.unitIdFor(
      LevelPlayPlacement.rewardedFeature,
    );
    if (unitId == null) return RewardOutcome.failed;

    await VShotsLevelPlay.instance.waitReady(
      timeout: const Duration(seconds: 6),
    );
    if (!VShotsLevelPlay.instance.initSucceeded) return RewardOutcome.failed;

    final ad = VShotsLevelPlay.instance.peekRewarded();
    if (ad == null) return RewardOutcome.failed;

    AdAnalytics.log('rewarded_started', placement: purpose);

    var ready = await ad.isAdReady();
    if (!ready) {
      final loaded = Completer<void>();
      final prev = VShotsLevelPlay.instance.rewardedLoadedHook;
      VShotsLevelPlay.instance.rewardedLoadedHook = () {
        if (!loaded.isCompleted) loaded.complete();
      };
      try {
        unawaited(ad.loadAd());
        await loaded.future.timeout(const Duration(seconds: 15));
      } catch (_) {
        // timeout / error — proceed with whatever is ready
      } finally {
        VShotsLevelPlay.instance.rewardedLoadedHook = prev;
      }
      ready = await ad.isAdReady();
    }
    if (!ready) return RewardOutcome.failed;

    // Wire the session: reward granted ONLY on SDK-confirmed completion.
    final result = Completer<RewardOutcome>();
    VShotsLevelPlay.instance.rewardSession = RewardSession(
      onGrant: () {
        try {
          onRewardGranted?.call();
        } catch (e) {
          debugPrint('[VShotsAds] reward grant error: $e');
        }
      },
      onClosed: (wasEarned) {
        if (!result.isCompleted) {
          result.complete(
            wasEarned ? RewardOutcome.completed : RewardOutcome.canceled,
          );
        }
      },
    );

    try {
      await ad.showAd(placementName: LevelPlayPlacement.rewardedFeature);
    } catch (e) {
      VShotsLevelPlay.instance.rewardSession = null;
      AdAnalytics.log('ad_load_failed', placement: purpose, detail: 'show: $e');
      return RewardOutcome.failed;
    }

    try {
      return await result.future.timeout(const Duration(seconds: 180));
    } on TimeoutException {
      VShotsLevelPlay.instance.rewardSession = null;
      return RewardOutcome.failed;
    }
  }
}

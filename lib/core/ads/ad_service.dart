// ═════════════════════════════════════════════════════════════════════════
// V Shots — VShotsAds (central ad facade, Unity LevelPlay backed)
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ad_analytics.dart';
import 'ad_policy.dart';
import 'levelplay_config.dart';
import 'levelplay_service.dart';
import 'player_sponsored_ad_policy.dart';

enum RewardOutcome { completed, canceled, failed }

class VShotsAds {
  VShotsAds._();

  static final VShotsAds instance = VShotsAds._();

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
      final loaded = Completer<void>();
      final prev = VShotsLevelPlay.instance.interstitialLoadedHook;
      VShotsLevelPlay.instance.interstitialLoadedHook = () {
        if (!loaded.isCompleted) loaded.complete();
      };
      try {
        VShotsLevelPlay.instance.requestInterstitialLoad();
        await loaded.future.timeout(const Duration(seconds: 3));
      } catch (_) {
      } finally {
        VShotsLevelPlay.instance.interstitialLoadedHook = prev;
      }
      ready = await ad.isAdReady();
    }
    if (!ready) return;

    policy.frequency.recordShown();
    AdAnalytics.log('interstitial_shown', placement: trigger);
    try {
      await ad.showAd(placementName: trigger);
    } catch (e) {
      debugPrint('[VShotsAds] interstitial show error: $e');
    }
  }

  Future<bool> showDiscoverySwipeInterstitial({
    required String trigger,
  }) async {
    final policy = AdPolicy.instance;
    if (!policy.canShowDiscoverySwipeInterstitial()) return false;
    final unitId = LevelPlayConfig.unitIdFor(
      LevelPlayPlacement.interstitialSessionBreak,
    );
    if (unitId == null) return false;

    await VShotsLevelPlay.instance.waitReady(
      timeout: const Duration(milliseconds: 500),
    );
    if (!VShotsLevelPlay.instance.initSucceeded) return false;

    final ad = VShotsLevelPlay.instance.peekInterstitial();
    if (ad == null) return false;

    final isReady = await ad.isAdReady();
    if (!isReady) {
      VShotsLevelPlay.instance.requestInterstitialLoad();
      return false;
    }

    final closed = Completer<void>();
    final prevHook = VShotsLevelPlay.instance.interstitialClosedHook;
    VShotsLevelPlay.instance.interstitialClosedHook = () {
      prevHook?.call();
      if (!closed.isCompleted) closed.complete();
    };

    policy.frequency.recordShown();
    AdAnalytics.log('interstitial_shown', placement: trigger);
    PlayerSponsoredAdPolicy.instance.noteExternalAdShown();

    try {
      await ad.showAd(placementName: trigger);
      await closed.future.timeout(const Duration(seconds: 45));
      return true;
    } catch (e) {
      debugPrint('[VShotsAds] discovery swipe interstitial error: $e');
      return false;
    } finally {
      VShotsLevelPlay.instance.interstitialClosedHook = prevHook;
    }
  }

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
        VShotsLevelPlay.instance.requestRewardedLoad();
        await loaded.future.timeout(const Duration(seconds: 15));
      } catch (_) {
      } finally {
        VShotsLevelPlay.instance.rewardedLoadedHook = prev;
      }
      ready = await ad.isAdReady();
    }
    if (!ready) return RewardOutcome.failed;

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
      await ad.showAd();
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

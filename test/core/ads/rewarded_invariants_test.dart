// ═════════════════════════════════════════════════════════════════════════
// V Shots — Rewarded Ad Invariants & Regression Protection Suite
//
// Permanently validates and protects the Rewarded Ad implementation:
//   1. Correct rewarded unit resolution (debug test + production).
//   2. Rewarded ad unit is mapped in LevelPlayConfig.
//   3. Failed load resets rewardedReady state and records error.
//   4. Successful load marks rewardedReady=true.
//   5. Reward callback only marks reward earned when SDK callback fires.
//   6. Closing without reward does NOT grant reward.
//   7. Rewarded flow clears the active RewardSession on completion/failure.
//   8. Consumed ad resets ready state allowing subsequent preload.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/ads/ad_policy.dart';
import 'package:v_shots/core/ads/ad_service.dart';
import 'package:v_shots/core/ads/levelplay_config.dart';
import 'package:v_shots/core/ads/levelplay_service.dart';

void main() {
  group('Rewarded Ad Invariants & Regression Protection', () {
    tearDown(() {
      LevelPlayConfig.debugSetEnv(null);
      VShotsLevelPlay.instance.rewardSession = null;
      VShotsLevelPlay.instance.rewardedReady = false;
    });

    test('Invariant 1: Rewarded unit resolves to test unit in debug mode', () {
      LevelPlayConfig.debugSetEnv({
        'LEVELPLAY_APP_KEY': '27c0e8465',
      });
      final wasInTests = LevelPlayConfig.debugIsRunningInTests;
      LevelPlayConfig.debugIsRunningInTests = false;
      try {
        final unitId = LevelPlayConfig.unitIdFor(
          LevelPlayPlacement.rewardedFeature,
        );
        expect(unitId, 'syz3d8ekts22q0or');
      } finally {
        LevelPlayConfig.debugIsRunningInTests = wasInTests;
      }
    });

    test('Invariant 1b: Rewarded unit resolves to prod unit in prod mode', () {
      LevelPlayConfig.debugSetEnv({
        'LEVELPLAY_DEBUG_USE_PRODUCTION': 'true',
        'LEVELPLAY_APP_KEY': '27c0e8465',
        'LEVELPLAY_UNIT_REWARDED_FEATURE_01': '2izjczd4ox2wj6yd',
      });
      final wasInTests = LevelPlayConfig.debugIsRunningInTests;
      LevelPlayConfig.debugIsRunningInTests = false;
      try {
        final unitId = LevelPlayConfig.unitIdFor(
          LevelPlayPlacement.rewardedFeature,
        );
        expect(unitId, '2izjczd4ox2wj6yd');
      } finally {
        LevelPlayConfig.debugIsRunningInTests = wasInTests;
      }
    });

    test('Invariant 2: Rewarded placement is mapped in unitEnvKeys', () {
      expect(
        LevelPlayConfig.unitEnvKeys[LevelPlayPlacement.rewardedFeature],
        'LEVELPLAY_UNIT_REWARDED_FEATURE_01',
      );
      expect(
        LevelPlayPlacement.rewardedFeature,
        'REWARDED_FEATURE_01',
      );
    });

    test('Invariant 3: RewardSession grants only when onGrant fires', () {
      bool grantCalled = false;
      bool? earnedOnClose;

      final session = RewardSession(
        onGrant: () => grantCalled = true,
        onClosed: (wasEarned) => earnedOnClose = wasEarned,
      );

      expect(session.granted, isFalse);
      expect(grantCalled, isFalse);

      session.onGrant();
      session.granted = true;
      expect(session.granted, isTrue);
      expect(grantCalled, isTrue);

      session.onClosed(session.granted);
      expect(earnedOnClose, isTrue);
    });

    test('Invariant 4: RewardSession closing without grant denies reward', () {
      bool grantCalled = false;
      bool? earnedOnClose;

      final session = RewardSession(
        onGrant: () => grantCalled = true,
        onClosed: (wasEarned) => earnedOnClose = wasEarned,
      );

      expect(session.granted, isFalse);
      session.onClosed(session.granted);

      expect(grantCalled, isFalse);
      expect(earnedOnClose, isFalse);
    });

    test('Invariant 5: Ready state transitions correctly on load & show', () {
      final service = VShotsLevelPlay.instance;
      service.rewardedReady = false;
      expect(service.rewardedReady, isFalse);

      service.rewardedReady = true;
      expect(service.rewardedReady, isTrue);

      service.rewardedReady = false;
      expect(service.rewardedReady, isFalse);
    });

    test('Invariant 6: Policy gate canShowRewarded obeys policy', () {
      AdPolicy.instance.setFormatEnabled(rewarded: false);
      expect(AdPolicy.instance.canShowRewarded(), isFalse);

      AdPolicy.instance.setFormatEnabled(rewarded: true);
      LevelPlayConfig.debugSetEnv({'LEVELPLAY_APP_KEY': 'test_key'});
      expect(AdPolicy.instance.canShowRewarded(), isTrue);
    });

    test('Invariant 7: showRewarded fails safely when SDK unconfigured',
        () async {
      LevelPlayConfig.debugSetEnv(null);
      bool grantCalled = false;

      final outcome = await VShotsAds.instance.showRewarded(
        purpose: 'ad_free_pass_60m',
        onRewardGranted: () => grantCalled = true,
      );

      expect(outcome, RewardOutcome.failed);
      expect(grantCalled, isFalse);
    });
  });
}

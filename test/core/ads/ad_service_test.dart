// ═════════════════════════════════════════════════════════════════════════
// V Shots — VShotsAds Fail-Safe Tests (Unity LevelPlay)
//
// In the test environment no ad SDK/plugins exist. These tests verify the
// contract that MATTERS when ads are unavailable: the service must never
// throw, must not touch the SDK when policy denies or LevelPlay is unconfigured,
// and must return graceful outcomes (normal app behavior continues).
//
// SDK-failure paths (no fill / channel errors) are wrapped in try/catch in
// the service and are exercised on real devices via the LevelPlay
// debugger / BrowserStack QA.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:v_shots/core/ads/ad_free_manager.dart';
import 'package:v_shots/core/ads/ad_frequency_controller.dart';
import 'package:v_shots/core/ads/ad_policy.dart';
import 'package:v_shots/core/ads/ad_service.dart';
import 'package:v_shots/core/ads/consent_manager.dart';
import 'package:v_shots/core/ads/levelplay_config.dart';
import 'package:v_shots/core/remote_config/remote_feature_flags.dart';

void main() {
  group('VShotsAds fail-safe (LevelPlay not configured)', () {
    setUp(() {
      LevelPlayConfig.debugSetEnv(
          null); // no app key → master OFF (default builds)
      RemoteFeatureFlags.instance.debugOverride(null);
      ConsentManager.instance.debugSetStatus(ConsentStatus.unknown);
      AdFreeManager.instance.debugSet(permanent: false, adFreeUntil: null);
      AdPolicy.instance.frequency = AdFrequencyController();
    });

    tearDown(() {
      LevelPlayConfig.debugSetEnv(null);
      RemoteFeatureFlags.instance.debugOverride(null);
    });

    test(
        'maybeShowInterstitial is a silent no-op when LevelPlay is unconfigured',
        () async {
      await expectLater(
        VShotsAds.instance.maybeShowInterstitial(trigger: 'tab_switch_0'),
        completes,
      );
    });

    test('showRewarded fails gracefully (no reward, no throw) when denied',
        () async {
      bool granted = false;
      final outcome = await VShotsAds.instance.showRewarded(
        purpose: 'ad_free_pass_60m',
        onRewardGranted: () => granted = true,
      );
      expect(outcome, RewardOutcome.failed);
      expect(granted, isFalse, reason: 'a denied reward must never be granted');
    });
  });

  group(
      'VShotsAds fail-safe (LevelPlay configured, SDK unavailable in test env)',
      () {
    setUp(() {
      LevelPlayConfig.debugSetEnv({
        'LEVELPLAY_APP_KEY': 'test-app-key',
        'LEVELPLAY_UNIT_INTERSTITIAL_SESSION_BREAK_01': 'test-unit',
      });
      RemoteFeatureFlags.instance.debugOverride(null);
      ConsentManager.instance.debugSetStatus(ConsentStatus.unknown);
      AdFreeManager.instance.debugSet(permanent: false, adFreeUntil: null);
      AdPolicy.instance.frequency = AdFrequencyController(
        appStartedAt: DateTime(2026, 8, 22, 9), // dwell satisfied
      );
    });

    tearDown(() {
      LevelPlayConfig.debugSetEnv(null);
      RemoteFeatureFlags.instance.debugOverride(null);
    });

    test('interstitial is a bounded no-op when the SDK never becomes ready',
        () async {
      // Policy allows, but VShotsMax.initialize() was never called (no SDK
      // in the test env) → waitReady times out (2 s) → initSucceeded=false
      // → the app simply continues. No throw.
      await expectLater(
        VShotsAds.instance.maybeShowInterstitial(trigger: 'tab_switch_1'),
        completes,
      );
    });
  });
}

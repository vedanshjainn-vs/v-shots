// ═════════════════════════════════════════════════════════════════════════
// V Shots — VShotsAds Fail-Safe Tests
//
// In the test environment no ad SDK/plugins exist. These tests verify the
// contract that MATTERS when ads are unavailable: the service must never
// throw, must not touch the SDK when policy denies, and must return
// graceful outcomes (normal app behavior continues).
//
// SDK-failure paths (no fill / channel errors) are wrapped in try/catch in
// the service and are exercised on real devices via BrowserStack QA.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:v_shots/core/ads/ad_config.dart';
import 'package:v_shots/core/ads/ad_free_manager.dart';
import 'package:v_shots/core/ads/ad_frequency_controller.dart';
import 'package:v_shots/core/ads/ad_policy.dart';
import 'package:v_shots/core/ads/ad_service.dart';
import 'package:v_shots/core/ads/consent_manager.dart';
import 'package:v_shots/core/remote_config/remote_feature_flags.dart';

void main() {
  group('VShotsAds fail-safe (ads disabled)', () {
    setUp(() {
      AdConfig.debugSetHasAnyAdUnitId(null); // master OFF (default builds)
      RemoteFeatureFlags.instance.debugOverride(null);
      ConsentManager.instance.debugSetStatus(ConsentStatus.unknown);
      AdFreeManager.instance.debugSet(permanent: false, adFreeUntil: null);
      AdPolicy.instance.frequency = AdFrequencyController();
    });

    tearDown(() {
      AdConfig.debugSetHasAnyAdUnitId(null);
      RemoteFeatureFlags.instance.debugOverride(null);
    });

    test('maybeShowInterstitial is a silent no-op when policy denies',
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

    test('warmUp is a silent no-op when ads are disabled', () async {
      await expectLater(VShotsAds.instance.warmUp(), completes);
    });

    test('ensureReady never throws', () async {
      final ready = await VShotsAds.instance
          .ensureReady(timeout: const Duration(milliseconds: 50));
      expect(ready, isA<bool>());
    });
  });
}

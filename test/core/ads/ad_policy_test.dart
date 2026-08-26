// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Policy Tests
//
// The central decision engine: master gate, emergency kill switch,
// premium/ad-free, consent, per-format toggles, placement restrictions,
// and interstitial frequency enforcement.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:v_shots/core/ads/levelplay_config.dart';
import 'package:v_shots/core/ads/ad_free_manager.dart';
import 'package:v_shots/core/ads/ad_frequency_controller.dart';
import 'package:v_shots/core/ads/ad_policy.dart';
import 'package:v_shots/core/ads/consent_manager.dart';
import 'package:v_shots/core/remote_config/remote_feature_flags.dart';

void main() {
  group('AdPolicy', () {
    setUp(() {
      // Deterministic baseline: LevelPlay not configured (ads OFF), no
      // overrides, and the debug-build test-credentials fallback disabled
      // so "unconfigured" really means unconfigured.
      // consent settled (unknown = not required), not ad-free, all formats
      // on, frequency budget fresh with dwell already satisfied.
      LevelPlayConfig.debugSetEnv(null);
      LevelPlayConfig.debugSetTestFallbackEnabled(false);
      RemoteFeatureFlags.instance.debugOverride(null);
      ConsentManager.instance.debugSetStatus(ConsentStatus.unknown);
      AdFreeManager.instance.debugSet(permanent: false, adFreeUntil: null);
      AdPolicy.instance.setFormatEnabled(
        native: true,
        interstitial: true,
        rewarded: true,
        banners: true,
      );
      AdPolicy.instance.frequency = AdFrequencyController(
        appStartedAt: DateTime(2026, 8, 22, 9), // dwell satisfied by test time
      );
    });

    tearDown(() {
      LevelPlayConfig.debugSetEnv(null);
      LevelPlayConfig.debugSetTestFallbackEnabled(true);
      RemoteFeatureFlags.instance.debugOverride(null);
    });

    void enableMaster() =>
        LevelPlayConfig.debugSetEnv({'LEVELPLAY_APP_KEY': 'test-app-key'});

    test('fails closed when LevelPlay is not configured (default store build)',
        () {
      final p = AdPolicy.instance;
      expect(p.adsAvailable, isFalse);
      expect(p.canShowNative(AdPlacement.home), isFalse);
      expect(p.canShowInterstitial(), isFalse);
      expect(p.canShowRewarded(), isFalse);
      expect(p.canShowBanner(AdPlacement.playlist), isFalse);
    });

    test('opens when the LevelPlay app key is configured', () {
      enableMaster();
      final p = AdPolicy.instance;
      expect(p.adsAvailable, isTrue);
      expect(p.canShowNative(AdPlacement.home), isTrue);
      expect(p.canShowNative(AdPlacement.search), isTrue);
      expect(p.canShowNative(AdPlacement.forYouFeed), isTrue);
      expect(p.canShowInterstitial(), isTrue);
      expect(p.canShowRewarded(), isTrue);
      expect(p.canShowBanner(AdPlacement.playlist), isTrue);
    });

    test('EMERGENCY remote flag (enable_ads=false) kills every placement', () {
      enableMaster();
      RemoteFeatureFlags.instance.debugOverride({'enable_ads': false});
      final p = AdPolicy.instance;
      expect(p.adsAvailable, isFalse);
      expect(p.canShowNative(AdPlacement.home), isFalse);
      expect(p.canShowInterstitial(), isFalse);
      expect(p.canShowRewarded(), isFalse);
      expect(p.canShowBanner(AdPlacement.library), isFalse);
    });

    test('missing emergency flag defaults to ON (no behavior change)', () {
      enableMaster();
      RemoteFeatureFlags.instance.debugOverride({}); // no enable_ads key
      expect(AdPolicy.instance.adsAvailable, isTrue);
    });

    test('ad-free user (rewarded pass) gets no ads anywhere', () {
      enableMaster();
      AdFreeManager.instance.debugSet(
        adFreeUntil: DateTime.now().add(const Duration(minutes: 60)),
      );
      expect(AdPolicy.instance.adsAvailable, isFalse);
      expect(AdPolicy.instance.canShowNative(AdPlacement.search), isFalse);
    });

    test('ad-free user (future premium flag) gets no ads anywhere', () {
      enableMaster();
      AdFreeManager.instance.debugSet(permanent: true);
      expect(AdPolicy.instance.adsAvailable, isFalse);
    });

    test('pending UMP consent blocks ads; settled consent allows them', () {
      enableMaster();
      ConsentManager.instance.debugSetStatus(ConsentStatus.required);
      expect(AdPolicy.instance.adsAvailable, isFalse);

      ConsentManager.instance.debugSetStatus(ConsentStatus.obtained);
      expect(AdPolicy.instance.adsAvailable, isTrue);

      ConsentManager.instance.debugSetStatus(ConsentStatus.notRequired);
      expect(AdPolicy.instance.adsAvailable, isTrue);
    });

    test('per-format toggles affect only their format', () {
      enableMaster();
      AdPolicy.instance.setFormatEnabled(native: false);
      final p = AdPolicy.instance;
      expect(p.canShowNative(AdPlacement.home), isFalse);
      expect(p.canShowInterstitial(), isTrue,
          reason: 'other formats keep working');

      AdPolicy.instance.setFormatEnabled(native: true, interstitial: false);
      expect(p.canShowInterstitial(), isFalse);
      expect(p.canShowNative(AdPlacement.home), isTrue);
    });

    test('banners are restricted to placements that fit the layout', () {
      enableMaster();
      final p = AdPolicy.instance;
      expect(p.canShowBanner(AdPlacement.playlist), isTrue);
      expect(p.canShowBanner(AdPlacement.library), isTrue);
      expect(p.canShowBanner(AdPlacement.home), isFalse);
      expect(p.canShowBanner(AdPlacement.search), isFalse);
      expect(p.canShowBanner(AdPlacement.player), isFalse);
    });

    test('no player placement is ever allowed (player stays clean)', () {
      enableMaster();
      expect(AdPolicy.instance.canShowBanner(AdPlacement.player), isFalse);
      // Native player slot does not exist in the app; policy exposes banners
      // for player only via canShowBanner (which is false above).
    });

    test('interstitial honors the centralized cooldown', () {
      enableMaster();
      final p = AdPolicy.instance;
      expect(p.canShowInterstitial(), isTrue);
      p.frequency.recordShown();
      expect(p.canShowInterstitial(), isFalse,
          reason: '180 s cooldown after a real show');
    });

    test('interstitial honors the session cap', () {
      enableMaster();
      AdPolicy.instance.frequency = AdFrequencyController(
        appStartedAt: DateTime(2026, 8, 22, 9),
        minInterval: Duration.zero,
        maxPerSession: 1,
        minDwell: Duration.zero,
      );
      final p = AdPolicy.instance;
      expect(p.canShowInterstitial(), isTrue);
      p.frequency.recordShown();
      expect(p.canShowInterstitial(), isFalse, reason: 'session cap reached');
    });

    test('diagnostics describe the current mode', () {
      enableMaster();
      expect(AdPolicy.instance.describe(), contains('mode='));
      expect(AdPolicy.instance.describe(), contains('adFree='));
    });
  });
}

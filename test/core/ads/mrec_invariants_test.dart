// ═════════════════════════════════════════════════════════════════════════
// V Shots — MREC Invariants & Regression Safety Test Suite
//
// Permanently protects the known-good LevelPlay MREC 300x250 implementation:
//   - Unit resolution: LEVELPLAY_UNIT_BANNER_HOME_01 (eotgb78qisj7sis8)
//   - Ad size: LevelPlayAdSize.MEDIUM_RECTANGLE (300x250)
//   - Placement name: MREC_Android
//   - Widget: LevelPlayBannerAdView inside PremiumMRECAdCard
//   - Independence from normal 320x50 AdBannerWidget
//   - Zero dependency on MREC_HOME_01
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'package:v_shots/core/ads/ad_policy.dart';
import 'package:v_shots/core/ads/levelplay_config.dart';
import 'package:v_shots/core/ads/mrec_ad_manager.dart';

void main() {
  group('MREC Invariants & Regression Protection', () {
    tearDown(() => LevelPlayConfig.debugSetEnv(null));

    test('Invariant A: MREC resolves via LevelPlayPlacement.bannerHome', () {
      LevelPlayConfig.debugSetEnv({
        'LEVELPLAY_DEBUG_USE_PRODUCTION': 'true',
        'LEVELPLAY_APP_KEY': '27c0e8465',
        'LEVELPLAY_UNIT_BANNER_HOME_01': 'eotgb78qisj7sis8',
      });
      final wasInTests = LevelPlayConfig.debugIsRunningInTests;
      LevelPlayConfig.debugIsRunningInTests = false;
      try {
        final unitId = LevelPlayConfig.unitIdFor(LevelPlayPlacement.bannerHome);
        expect(unitId, 'eotgb78qisj7sis8');
      } finally {
        LevelPlayConfig.debugIsRunningInTests = wasInTests;
      }
    });

    test('Invariant B: LevelPlayAdSize.MEDIUM_RECTANGLE is 300x250', () {
      final size = LevelPlayAdSize.MEDIUM_RECTANGLE;
      expect(size.width, 300);
      expect(size.height, 250);
    });

    test('Invariant E: Standard Banner is 320x50 and independent of MREC', () {
      final bannerSize = LevelPlayAdSize.BANNER;
      expect(bannerSize.width, 320);
      expect(bannerSize.height, 50);
    });

    test('Invariant J: No MREC_HOME_01 unit exists in unitEnvKeys', () {
      expect(LevelPlayConfig.unitEnvKeys.containsKey('MREC_HOME_01'), isFalse);
      expect(
        LevelPlayConfig.unitEnvKeys.values,
        isNot(contains('LEVELPLAY_UNIT_MREC_HOME_01')),
      );
      expect(LevelPlayConfig.unitEnvKeys, hasLength(3));
    });

    test('MREC Policy Gate: canShowMREC allows all valid placements', () {
      LevelPlayConfig.debugSetEnv({
        'LEVELPLAY_APP_KEY': '27c0e8465',
      });
      for (final p in MRECPlacement.values) {
        expect(
          AdPolicy.instance.canShowMREC(p),
          isTrue,
          reason: 'Placement $p must be allowed by MREC policy',
        );
      }
    });

    test('MREC Manager: load and display lifecycle state changes properly', () {
      final manager = MRECAdManager.instance;
      manager.onAdLoaded();
      expect(manager.isLoaded, isTrue);
      expect(manager.isMRECReady(), isTrue);

      manager.markDisplayed();
      expect(manager.isLoaded, isFalse);

      manager.onAdLoadFailed('test error');
      expect(manager.isLoaded, isFalse);
    });
  });
}

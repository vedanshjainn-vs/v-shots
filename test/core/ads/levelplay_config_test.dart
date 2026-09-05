// ═════════════════════════════════════════════════════════════════════════
// V Shots — LevelPlayConfig Tests
//
// Stable placement identifiers, env-based configuration, fail-safe
// behavior when unconfigured, debug test-credential isolation (debug
// builds only), and credential separation (server keys never read by
// client config).
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/ads/levelplay_config.dart';

void main() {
  group('LevelPlayConfig', () {
    tearDown(() => LevelPlayConfig.debugSetEnv(null));

    test('all 8 stable placement identifiers are defined and unique', () {
      const ids = [
        LevelPlayPlacement.homeNative,
        LevelPlayPlacement.discoveryNative,
        LevelPlayPlacement.playerNative,
        LevelPlayPlacement.libraryNative,
        LevelPlayPlacement.searchNative,
        LevelPlayPlacement.interstitialSessionBreak,
        LevelPlayPlacement.rewardedFeature,
        LevelPlayPlacement.bannerHome,
      ];
      expect(ids, hasLength(8));
      expect(ids.toSet(), hasLength(8));
      expect(LevelPlayConfig.unitEnvKeys, hasLength(3));
      for (final p in [
        LevelPlayPlacement.interstitialSessionBreak,
        LevelPlayPlacement.rewardedFeature,
        LevelPlayPlacement.bannerHome,
      ]) {
        final envKey = LevelPlayConfig.unitEnvKeys[p];
        expect(envKey, isNotNull);
        expect(envKey, startsWith('LEVELPLAY_UNIT_'));
      }
    });

    test('unknown placement returns null (no crash)', () {
      LevelPlayConfig.debugSetEnv({'LEVELPLAY_APP_KEY': 'k'});
      expect(LevelPlayConfig.unitIdFor('NOT_A_PLACEMENT'), isNull);
    });

    test('native placements never require a per-placement unit', () {
      LevelPlayConfig.debugSetEnv({'LEVELPLAY_APP_KEY': 'k'});
      for (final p in [
        LevelPlayPlacement.homeNative,
        LevelPlayPlacement.discoveryNative,
        LevelPlayPlacement.playerNative,
        LevelPlayPlacement.libraryNative,
        LevelPlayPlacement.searchNative,
      ]) {
        expect(LevelPlayConfig.unitEnvKeys[p], isNull,
            reason: 'native placement $p must be app-level');
      }
    });

    test(
        'debug build uses official Unity TEST credentials even when prod is injected',
        () {
      LevelPlayConfig.debugSetEnv({
        'LEVELPLAY_APP_KEY': 'prod-app-key',
        'LEVELPLAY_UNIT_INTERSTITIAL_SESSION_BREAK_01': 'prod-inter-unit',
        'LEVELPLAY_UNIT_REWARDED_FEATURE_01': 'prod-rewarded-unit',
        'LEVELPLAY_UNIT_BANNER_HOME_01': 'prod-banner-unit',
      });
      final wasInTests = LevelPlayConfig.debugIsRunningInTests;
      LevelPlayConfig.debugIsRunningInTests = false;
      try {
        if (kDebugMode) {
          expect(LevelPlayConfig.hasProductionConfig, isTrue);
          expect(LevelPlayConfig.isConfigured, isTrue);
          expect(LevelPlayConfig.usingTestCredentials, isTrue);
          expect(LevelPlayConfig.appKey, '25b63cf85');
          expect(
            LevelPlayConfig.unitIdFor(
              LevelPlayPlacement.interstitialSessionBreak,
            ),
            'h3xw38h9214adgxo',
          );
          expect(
            LevelPlayConfig.unitIdFor(LevelPlayPlacement.rewardedFeature),
            'syz3d8ekts22q0or',
          );
          expect(
            LevelPlayConfig.unitIdFor(LevelPlayPlacement.bannerHome),
            '4fpetq4lhe5lsw3e',
          );
        }
      } finally {
        LevelPlayConfig.debugIsRunningInTests = wasInTests;
      }
    });

    test('debug build can explicitly opt into production credentials', () {
      LevelPlayConfig.debugSetEnv({
        'LEVELPLAY_DEBUG_USE_PRODUCTION': 'true',
        'LEVELPLAY_APP_KEY': 'prod-app-key',
        'LEVELPLAY_UNIT_INTERSTITIAL_SESSION_BREAK_01': 'prod-inter-unit',
      });
      final wasInTests = LevelPlayConfig.debugIsRunningInTests;
      LevelPlayConfig.debugIsRunningInTests = false;
      try {
        if (kDebugMode) {
          expect(LevelPlayConfig.usingTestCredentials, isFalse);
          expect(LevelPlayConfig.appKey, 'prod-app-key');
          expect(
            LevelPlayConfig.unitIdFor(
              LevelPlayPlacement.interstitialSessionBreak,
            ),
            'prod-inter-unit',
          );
        }
      } finally {
        LevelPlayConfig.debugIsRunningInTests = wasInTests;
      }
    });

    test(
        'debug build falls back to official Unity TEST credentials when no prod key exists',
        () {
      LevelPlayConfig.debugSetEnv({});
      final wasInTests = LevelPlayConfig.debugIsRunningInTests;
      LevelPlayConfig.debugIsRunningInTests = false;
      try {
        if (kDebugMode) {
          expect(LevelPlayConfig.isConfigured, isTrue);
          expect(LevelPlayConfig.usingTestCredentials, isTrue);
          expect(
            LevelPlayConfig.unitIdFor(
              LevelPlayPlacement.interstitialSessionBreak,
            ),
            isNotNull,
          );
          expect(
            LevelPlayConfig.unitIdFor(LevelPlayPlacement.rewardedFeature),
            isNotNull,
          );
          expect(
            LevelPlayConfig.unitIdFor(LevelPlayPlacement.bannerHome),
            isNotNull,
          );
        }
      } finally {
        LevelPlayConfig.debugIsRunningInTests = wasInTests;
      }
    });

    test('server-side credentials are NOT part of client config', () {
      for (final key in LevelPlayConfig.unitEnvKeys.values) {
        expect(key, isNot(contains('MANAGEMENT')));
        expect(key, isNot(contains('REPORT')));
        expect(key, isNot(contains('EVENT')));
      }
    });
  });
}

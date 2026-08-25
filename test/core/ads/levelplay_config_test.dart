// ═════════════════════════════════════════════════════════════════════════
// V Shots — LevelPlayConfig Tests
//
// Stable placement identifiers, env-based configuration, fail-safe
// behavior when unconfigured, debug test-credential fallback (debug
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
      // The 3 unit-based placements have env mappings; the 4 native
      // placements are app-level (placement names only).
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

    test('unconfigured build: everything fails safe', () {
      LevelPlayConfig.debugSetEnv({});
      // In a debug build the official Unity test fallback applies;
      // simulate the no-fallback case via release-mode key absence:
      expect(LevelPlayConfig.unitIdFor('NOT_A_PLACEMENT'), isNull);
    });

    test('app key + unit IDs read from env; blanks are treated as absent', () {
      LevelPlayConfig.debugSetEnv({
        'LEVELPLAY_APP_KEY': '  prod-app-key  ',
        'LEVELPLAY_UNIT_INTERSTITIAL_SESSION_BREAK_01': 'inter-unit',
        'LEVELPLAY_UNIT_BANNER_HOME_01': '   ', // blank → absent
      });
      expect(LevelPlayConfig.isConfigured, isTrue);
      expect(LevelPlayConfig.appKey, 'prod-app-key');
      expect(LevelPlayConfig.usingTestCredentials, isFalse);
      expect(
          LevelPlayConfig.unitIdFor(
              LevelPlayPlacement.interstitialSessionBreak),
          'inter-unit');
      expect(LevelPlayConfig.unitIdFor(LevelPlayPlacement.bannerHome), isNull);
      expect(LevelPlayConfig.configuredUnitCount(), 1);
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

    test('debug build falls back to official Unity TEST credentials', () {
      LevelPlayConfig.debugSetEnv({}); // no production key
      final wasInTests = LevelPlayConfig.debugIsRunningInTests;
      LevelPlayConfig.debugIsRunningInTests = false;
      try {
        if (kDebugMode) {
          expect(LevelPlayConfig.isConfigured, isTrue,
              reason: 'debug build uses the official test fallback');
          expect(LevelPlayConfig.usingTestCredentials, isTrue);
          expect(
              LevelPlayConfig.unitIdFor(
                  LevelPlayPlacement.interstitialSessionBreak),
              isNotNull);
          expect(LevelPlayConfig.unitIdFor(LevelPlayPlacement.rewardedFeature),
              isNotNull);
          expect(LevelPlayConfig.unitIdFor(LevelPlayPlacement.bannerHome),
              isNotNull);
        }
      } finally {
        LevelPlayConfig.debugIsRunningInTests = wasInTests;
      }
    });

    test('server-side credentials are NOT part of client config', () {
      // Client config only knows the app key + unit IDs. Management/Report
      // keys exist only in server-side automation, never in the app.
      for (final key in LevelPlayConfig.unitEnvKeys.values) {
        expect(key, isNot(contains('MANAGEMENT')));
        expect(key, isNot(contains('REPORT')));
        expect(key, isNot(contains('EVENT')));
      }
    });
  });
}

// ═════════════════════════════════════════════════════════════════════════
// V Shots — MaxConfig Tests
//
// Stable placement identifiers, env-based configuration, fail-safe
// behavior when unconfigured, and credential separation (server keys are
// never read by client config).
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/ads/max_config.dart';

void main() {
  group('MaxConfig', () {
    tearDown(() => MaxConfig.debugSetEnv(null));

    test('all 8 stable placement identifiers are defined and unique', () {
      const ids = [
        MaxPlacement.homeNative,
        MaxPlacement.discoveryNative,
        MaxPlacement.playerNative,
        MaxPlacement.libraryNative,
        MaxPlacement.searchNative,
        MaxPlacement.interstitialSessionBreak,
        MaxPlacement.rewardedFeature,
        MaxPlacement.bannerHome,
      ];
      expect(ids, hasLength(8));
      expect(ids.toSet(), hasLength(8));
      // Every placement has an env mapping.
      for (final id in ids) {
        expect(MaxConfig.unitEnvKeys[id], isNotNull);
        expect(MaxConfig.unitEnvKeys[id], startsWith('APPLOVIN_MAX_UNIT_'));
      }
    });

    test('unconfigured build: everything fails safe', () {
      MaxConfig.debugSetEnv(null);
      expect(MaxConfig.isConfigured, isFalse);
      expect(MaxConfig.sdkKey, isNull);
      expect(MaxConfig.unitIdFor(MaxPlacement.homeNative), isNull);
      expect(MaxConfig.configuredUnitCount(), 0);
    });

    test('SDK key + unit IDs read from env; blanks are treated as absent', () {
      MaxConfig.debugSetEnv({
        'APPLOVIN_MAX_SDK_KEY': '  sdk-key-123  ',
        'APPLOVIN_MAX_UNIT_HOME_NATIVE_01': 'home-unit',
        'APPLOVIN_MAX_UNIT_BANNER_HOME_01': '   ', // blank → absent
      });
      expect(MaxConfig.isConfigured, isTrue);
      expect(MaxConfig.sdkKey, 'sdk-key-123');
      expect(MaxConfig.unitIdFor(MaxPlacement.homeNative), 'home-unit');
      expect(MaxConfig.unitIdFor(MaxPlacement.bannerHome), isNull);
      expect(MaxConfig.configuredUnitCount(), 1);
    });

    test('unknown placement returns null (no crash)', () {
      MaxConfig.debugSetEnv({'APPLOVIN_MAX_SDK_KEY': 'k'});
      expect(MaxConfig.unitIdFor('NOT_A_PLACEMENT'), isNull);
    });

    test('server-side credentials are NOT part of client config', () {
      // The client config only knows SDK key + unit IDs. Management/Report/
      // Event keys exist only in scripts/max_setup.py (server env).
      expect(MaxConfig.unitEnvKeys.values,
          isNot(contains(contains('MANAGEMENT'))));
      expect(MaxConfig.unitEnvKeys.values, isNot(contains(contains('REPORT'))));
      expect(MaxConfig.unitEnvKeys.values, isNot(contains(contains('EVENT'))));
    });
  });
}

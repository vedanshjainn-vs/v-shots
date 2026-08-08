// ════════════════════════════════════════════════
// Project Lyra — Feature Flag Tests
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lyra/core/feature_flags/models/feature_flag.dart';
import 'package:project_lyra/core/feature_flags/providers/feature_flag_service.dart';

void main() {
  group('FeatureFlagService', () {
    late FeatureFlagService service;

    setUp(() {
      service = FeatureFlagService();
      service.setUserId('test_user_123');
    });

    tearDown(() {
      service.clearOverrides();
    });

    test('returns false for unknown flag', () {
      expect(service.isEnabled('unknown_flag'), false);
    });

    test('returns default value for boolean flag', () {
      service.registerFlags([
        const FeatureFlag(
          key: 'test_flag',
          type: FeatureFlagType.boolean,
          defaultValue: true,
        ),
      ]);

      expect(service.isEnabled('test_flag'), true);
    });

    test('runtime override takes precedence', () {
      service.registerFlags([
        const FeatureFlag(
          key: 'test_flag',
          type: FeatureFlagType.boolean,
          defaultValue: false,
        ),
      ]);

      service.override('test_flag', true);

      expect(service.isEnabled('test_flag'), true);
    });

    test('kill switch disables flag', () {
      service.registerFlags([
        const FeatureFlag(
          key: 'test_flag',
          type: FeatureFlagType.killSwitch,
          defaultValue: true,
          isKillSwitchActive: true,
        ),
      ]);

      expect(service.isEnabled('test_flag'), false);
    });

    test('remote values override local defaults', () {
      service.registerFlags([
        const FeatureFlag(
          key: 'test_flag',
          type: FeatureFlagType.boolean,
          defaultValue: false,
        ),
      ]);

      service.updateRemoteValues({'test_flag': true});

      expect(service.isEnabled('test_flag'), true);
    });

    test('experiment returns variant', () {
      service.registerFlags([
        const FeatureFlag(
          key: 'ab_test',
          type: FeatureFlagType.experiment,
          defaultValue: 'control',
          variants: {'control': 'control', 'variant_a': 'variant_a'},
        ),
      ]);

      final variant = service.getExperiment('ab_test');

      expect(variant, isNotNull);
      expect(['control', 'variant_a'], contains(variant));
    });

    test('clearOverrides removes all overrides', () {
      service.override('flag1', true);
      service.override('flag2', 'value');
      service.clearOverrides();

      expect(service.isEnabled('flag1'), false);
      expect(service.getValue('flag2', 'default'), 'default');
    });
  });
}

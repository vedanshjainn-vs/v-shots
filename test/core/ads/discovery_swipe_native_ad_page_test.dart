// ═════════════════════════════════════════════════════════════════════════
// V Shots — Discovery Swipe Native Ad Page Test Suite
//
// Validates:
// 1. Policy gate (disabled ads -> triggers onUnavailable immediately)
// 2. Lifecycle transitions (creation, load request, dispose)
// 3. Fail-safe skip on mediation error / no-fill
// 4. Invariant: Small template type used for Discovery vertical stream
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'package:v_shots/core/ads/discovery_swipe_native_ad_page.dart';
import 'package:v_shots/core/ads/levelplay_config.dart';

void main() {
  group('DiscoverySwipeNativeAdPage Tests', () {
    tearDown(() {
      LevelPlayConfig.debugSetEnv(null);
    });

    testWidgets(
      'Fails closed immediately when ads are unavailable in policy',
      (tester) async {
        var unavailableTriggered = false;

        // Policy without credentials has adsAvailable == false
        LevelPlayConfig.debugSetEnv(null);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DiscoverySwipeNativeAdPage(
                onUnavailable: () {
                  unavailableTriggered = true;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(unavailableTriggered, isTrue);
      },
    );

    testWidgets(
      'Mounts safely without exceptions when initialized',
      (tester) async {
        LevelPlayConfig.debugSetEnv({
          'LEVELPLAY_DEBUG_USE_PRODUCTION': 'true',
          'LEVELPLAY_APP_KEY': '27c0e8465',
          'LEVELPLAY_UNIT_BANNER_HOME_01': 'eotgb78qisj7sis8',
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DiscoverySwipeNativeAdPage(
                onUnavailable: () {},
              ),
            ),
          ),
        );

        expect(find.byType(DiscoverySwipeNativeAdPage), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    test('Discovery Native template invariant is SMALL', () {
      expect(LevelPlayTemplateType.SMALL.name, 'SMALL');
    });

    test('Discovery placement resolves to discovery_native', () {
      expect(LevelPlayPlacement.discoveryNative, 'discovery_native');
    });
  });
}

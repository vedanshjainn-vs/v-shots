// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — Onboarding Finish navigation regression test (Test 13)
//
// Verifies the real bug fix: after a fresh install, pressing Finish MUST be
// able to navigate using the onboarding screen's OWN context (not a captured
// parent context that may already be unmounted). Regression for
// "Finish does nothing until app is killed + reopened".
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/preferences/user_preferences.dart';
import 'package:v_shots/features/onboarding/content_preferences_onboarding.dart';

void main() {
  testWidgets('Finish navigates using the onboarding screen\'s own context', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesStore.instance.initialize();

    bool navigated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => ContentPreferencesOnboarding(
            onComplete: (onboardCtx) {
              navigated = true;
              // If the callback context were dead/unmounted, this would throw.
              Navigator.of(onboardCtx).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('HOME_SCREEN')),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Step 0 (country, default India) -> Next
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    // Step 1 (languages) -> Next
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    // Step 2 (genres) -> Finish
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    // The callback fired AND navigation succeeded (marker screen shown).
    expect(navigated, isTrue);
    expect(find.text('HOME_SCREEN'), findsOneWidget);
    // Preferences are persisted + onboarding marked complete.
    expect(PreferencesStore.instance.preferences.onboardingCompleted, isTrue);
  });
}

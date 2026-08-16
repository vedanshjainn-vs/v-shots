// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Widget Tests (Nova 4-Tab Edition)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/storage/personalization_store.dart';
import 'package:v_shots/main.dart';
import 'package:v_shots/features/onboarding/onboarding_screen.dart';
import 'package:v_shots/shared/widgets/bottom_tab_bar.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  Future<void> advancePastSplash(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
  }

  group('V Shots App Tests', () {
    testWidgets('App launches and shows splash screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const VShotsApp());

      // Splash screen shows the app branding
      expect(find.text('V Shots'), findsWidgets);

      // Advance past the splash timer so no timers stay pending.
      await advancePastSplash(tester);
    });

    testWidgets(
      'first launch (not onboarded) shows onboarding after splash',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await PersonalizationStore.instance.reset();
        await PersonalizationStore.instance.initialize();

        await tester.pumpWidget(const VShotsApp());
        await advancePastSplash(tester);

        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.text('Personalize your feed'), findsNothing,
            reason: 'personalize is the last page, not the first');
      },
    );

    testWidgets(
      'returning user (onboarded) goes straight to the 4-tab shell',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await PersonalizationStore.instance.reset();
        await PersonalizationStore.instance.initialize();
        await PersonalizationStore.instance.completeOnboarding(
          languages: ['Hindi'],
          genres: ['Romantic'],
        );

        await tester.pumpWidget(const VShotsApp());
        await advancePastSplash(tester);

        // MainShell shows the Nova BottomTabBar with 4 destinations
        expect(find.byType(BottomTabBar), findsOneWidget);
        expect(find.text('Home'), findsWidgets);
        expect(find.byType(OnboardingScreen), findsNothing);
      },
    );

    testWidgets(
      'completing onboarding lands on the 4-tab shell',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await PersonalizationStore.instance.reset();
        await PersonalizationStore.instance.initialize();

        await tester.pumpWidget(const VShotsApp());
        await advancePastSplash(tester);

        expect(find.byType(OnboardingScreen), findsOneWidget);

        // Swipe through to the personalize page and tap Get Started.
        final onGetStarted = find.text('Get Started');
        for (var i = 0; i < 4 && onGetStarted.evaluate().isEmpty; i++) {
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
        }

        await tester.tap(onGetStarted);
        // Home's shimmer/equalizer animate continuously, so pumpAndSettle
        // would never settle — use fixed pumps for the route transition.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(BottomTabBar), findsOneWidget);
        expect(PersonalizationStore.instance.onboarded, isTrue);
      },
    );
  });
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _TestHttpClient();
}

class _TestHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

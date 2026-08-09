// ════════════════════════════════════════════════
// V Shots — Widget Tests
// ════════════════════════════════════════════════
//
// NOTE: this file previously referenced a `LoginScreen` widget that no
// longer exists in lib/main.dart (the current app flow goes straight
// to the splash -> MainShell with a Home/Search/Library/Profile tab
// bar; sign-in now lives inside ProfileScreen, not a separate
// full-screen login flow). That stale reference caused a real
// `flutter analyze` error (undefined_function) — fixed here by testing
// against the actual current widget tree instead of a screen that was
// removed at some point without this test being updated.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:v_shots/main.dart';

void main() {
  group('V Shots App Tests', () {
    testWidgets('App launches and shows splash screen', (WidgetTester tester) async {
      await tester.pumpWidget(const VShotsApp());

      // Splash screen shows the app name and tagline (see SplashScreen
      // in lib/main.dart).
      expect(find.text('V Shots'), findsOneWidget);
    });

    testWidgets('Splash navigates to the main tab shell after delay',
        (WidgetTester tester) async {
      await tester.pumpWidget(const VShotsApp());

      // SplashScreen navigates via Future.delayed — pump past that,
      // then settle any resulting animations.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // MainShell shows a bottom NavigationBar with these destinations
      // (see MainShell in lib/main.dart) — this is the real post-splash
      // landing state today, not a separate login screen.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
    });
  });
}

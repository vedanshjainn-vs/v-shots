// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Widget Tests (Nova 4-Tab Edition)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/main.dart';
import 'package:v_shots/shared/widgets/bottom_tab_bar.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  group('V Shots App Tests', () {
    testWidgets('App launches and shows splash screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const VShotsApp());

      // Splash screen shows the app branding
      expect(find.text('V Shots'), findsWidgets);

      // Advance past splash delay
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Splash navigates to the main 4-tab shell after delay', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const VShotsApp());

      // Advance past splash timer
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));

      // MainShell shows the Nova BottomTabBar with 4 destinations (Home, Discover, Search, Profile)
      expect(find.byType(BottomTabBar), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
    });
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

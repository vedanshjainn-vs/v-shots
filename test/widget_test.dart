// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Widget Tests (Nova Edition)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/main.dart';
import 'package:v_shots/shared/widgets/bottom_tab_bar.dart';

void main() {
  group('V Shots App Tests', () {
    testWidgets('App launches and shows splash screen', (WidgetTester tester) async {
      await tester.pumpWidget(const VShotsApp());

      // Splash screen shows the app name
      expect(find.text('V Shots'), findsWidgets);

      // Advance past splash delay and background retries
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Splash navigates to the main tab shell after delay',
        (WidgetTester tester) async {
      await tester.pumpWidget(const VShotsApp());

      // Advance past splash timer and background retries
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));

      // MainShell shows the Nova BottomTabBar with Home destination
      expect(find.byType(BottomTabBar), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
    });
  });
}

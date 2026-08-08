// ════════════════════════════════════════════════
// V Shots — Widget Tests
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:v_shots/main.dart';

void main() {
  group('V Shots App Tests', () {
    testWidgets('App launches and shows splash screen', (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const VShotsApp());

      // Verify splash screen appears
      expect(find.text('V Shots'), findsOneWidget);
      expect(find.text('Your music, your way'), findsOneWidget);
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('Splash navigates to login after delay', (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const VShotsApp());

      // Wait for splash animation and navigation
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Verify login screen appears
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('Login screen has required fields', (WidgetTester tester) async {
      // Build login screen directly
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Verify login form elements
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text("Don't have an account?"), findsOneWidget);
    });
  });
}

// ════════════════════════════════════════════════
// Project Lyra — Test Helpers
// ════════════════════════════════════════════════
//
// Reusable test utilities and setup functions.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a widget in a [MaterialApp] and [ProviderScope] for testing.
Widget createTestApp({
  required Widget child,
  List<Override> overrides = const [],
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: theme ?? ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: child),
    ),
  );
}

/// Pumps a widget and settles all animations.
Future<void> pumpAndSettle(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(createTestApp(child: widget, overrides: overrides));
  await tester.pumpAndSettle();
}

/// Creates a test [ProviderContainer] with optional overrides.
ProviderContainer createTestContainer({
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

/// Asserts that a [Finder] finds exactly one widget.
void expectOneWidget(Finder finder) {
  expect(finder, findsOneWidget);
}

/// Asserts that a [Finder] finds no widgets.
void expectNoWidget(Finder finder) {
  expect(finder, findsNothing);
}

/// Asserts that a [Finder] finds exactly [count] widgets.
void expectWidgetCount(Finder finder, int count) {
  expect(finder, findsNWidgets(count));
}

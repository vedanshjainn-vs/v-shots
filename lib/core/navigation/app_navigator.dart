import 'package:flutter/material.dart';

/// Root navigator. Wired from [MaterialApp.navigatorKey] in main.dart.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Builds the post-deletion splash/onboarding screen. Assigned from main.dart
/// to avoid a circular import with Settings.
typedef AppRootBuilder = Widget Function();

AppRootBuilder? appRootBuilder;

/// Replaces the entire stack with the app root (splash → onboarding/login).
void restartToAppRoot() {
  final nav = appNavigatorKey.currentState;
  final build = appRootBuilder;
  if (nav == null || build == null) return;
  nav.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => build()),
    (route) => false,
  );
}

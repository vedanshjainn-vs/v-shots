// ════════════════════════════════════════════════
// V Shots — Entry Point
// ════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await AppStartup.initialize();

  runApp(
    const ProviderScope(
      child: _VShotsApp(),
    ),
  );
}

class _VShotsApp extends StatelessWidget {
  const _VShotsApp();

  @override
  Widget build(BuildContext context) {
    return AppStartup.createApp();
  }
}

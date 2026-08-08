// ════════════════════════════════════════════════
// V Shots — App Startup
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/supabase/supabase_client.dart';
import 'app.dart';

/// Orchestrates cold-start initialization.
abstract final class AppStartup {
  static Future<void> initialize() async {
    // Initialize Hive
    await Hive.initFlutter();

    // Initialize Supabase
    await LyraSupabase.instance.initialize();
  }

  static Widget createApp() => const VShotsApp();
}

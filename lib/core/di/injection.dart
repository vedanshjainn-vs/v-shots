// ════════════════════════════════════════════════
// Project Lyra — Dependency Injection
// ════════════════════════════════════════════════
//
// Central Riverpod provider definitions.
// Organized by layer: infrastructure → data → domain → presentation.
// ════════════════════════════════════════════════

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/environment/env.dart';
import '../network/dio_client.dart';
import '../network/network_info.dart';
import '../storage/hive_storage.dart';
import '../storage/local_storage.dart';
import '../storage/shared_prefs_storage.dart';
import 'providers/network_providers.dart';
import 'providers/storage_providers.dart';

// ── Infrastructure Providers ─────────────────
// These are app-wide singletons.

/// Dio HTTP client.
final dioProvider = Provider<Dio>((ref) {
  return DioClient.create();
});

/// Network connectivity checker.
final networkInfoProvider = Provider<NetworkInfo>((ref) {
  final info = NetworkInfoImpl();
  ref.onDispose(info.dispose);
  return info;
});

/// SharedPreferences storage.
final sharedPrefsProvider = FutureProvider<SharedPrefsStorage>((ref) {
  return SharedPrefsStorage.create();
});

/// Hive storage (cache box).
final hiveCacheProvider = FutureProvider<HiveStorage>((ref) {
  return HiveStorage.open('cache_box');
});

/// Hive storage (user data box).
final hiveUserProvider = FutureProvider<HiveStorage>((ref) {
  return HiveStorage.open('user_box');
});

/// Hive storage (playback box).
final hivePlaybackProvider = FutureProvider<HiveStorage>((ref) {
  return HiveStorage.open('playback_box');
});

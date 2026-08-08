// ════════════════════════════════════════════════
// Project Lyra — Storage Providers
// ════════════════════════════════════════════════
//
// Riverpod providers for local storage.
// Lazy-initialized for fast cold start.
// ════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/hive_storage.dart';
import '../../storage/local_storage.dart';
import '../../storage/shared_prefs_storage.dart';

/// SharedPreferences instance.
final sharedPreferencesProvider = FutureProvider<SharedPrefsStorage>((ref) async {
  return SharedPrefsStorage.create();
});

/// Generic Hive box provider.
final hiveStorageProvider = FutureProvider.family<HiveStorage, String>((ref, boxName) async {
  final storage = await HiveStorage.open(boxName);
  ref.onDispose(() {
    // Box stays open for app lifetime; closed on app exit.
  });
  return storage;
});

/// App settings storage (SharedPreferences).
final settingsStorageProvider = FutureProvider<LocalStorage>((ref) async {
  return ref.watch(sharedPreferencesProvider.future);
});

/// Cache storage (Hive).
final cacheStorageProvider = FutureProvider<LocalStorage>((ref) async {
  return ref.watch(hiveStorageProvider('cache_box').future);
});

/// User data storage (Hive).
final userStorageProvider = FutureProvider<LocalStorage>((ref) async {
  return ref.watch(hiveStorageProvider('user_box').future);
});

/// Playback state storage (Hive).
final playbackStorageProvider = FutureProvider<LocalStorage>((ref) async {
  return ref.watch(hiveStorageProvider('playback_box').future);
});

/// Download storage (Hive).
final downloadStorageProvider = FutureProvider<LocalStorage>((ref) async {
  return ref.watch(hiveStorageProvider('download_box').future);
});

/// Search history storage (Hive).
final searchHistoryStorageProvider = FutureProvider<LocalStorage>((ref) async {
  return ref.watch(hiveStorageProvider('search_history_box').future);
});

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class LevelPlayPlacement {
  static const String homeNative = 'HOME_NATIVE_01';
  static const String discoveryNative = 'DISCOVERY_NATIVE_01';
  static const String playerNative = 'PLAYER_NATIVE_01';
  static const String libraryNative = 'LIBRARY_NATIVE_01';
  static const String searchNative = 'SEARCH_NATIVE_01';
  static const String interstitialSessionBreak = 'INTERSTITIAL_SESSION_BREAK_01';
  static const String rewardedFeature = 'REWARDED_FEATURE_01';
  static const String bannerHome = 'BANNER_HOME_01';
}

class LevelPlayConfig {
  LevelPlayConfig._();

  static const Map<String, String> unitEnvKeys = {
    LevelPlayPlacement.interstitialSessionBreak:
        'LEVELPLAY_UNIT_INTERSTITIAL_SESSION_BREAK_01',
    LevelPlayPlacement.rewardedFeature: 'LEVELPLAY_UNIT_REWARDED_FEATURE_01',
    // Preferred name for the real 300x250 MREC ad unit.
    LevelPlayPlacement.bannerHome: 'LEVELPLAY_UNIT_MREC_300X250_01',
  };

  static const String _testAppKey = '25b63cf85';
  static const String _testInterstitialUnit = 'h3xw38h9214adgxo';
  static const String _testRewardedUnit = 'syz3d8ekts22q0or';
  static const String _testBannerUnit = '4fpetq4lhe5lsw3e';

  static Map<String, String>? _debugEnv;

  @visibleForTesting
  static void debugSetEnv(Map<String, String>? values) => _debugEnv = values;

  static bool debugTestFallbackEnabled = true;

  @visibleForTesting
  static void debugSetTestFallbackEnabled(bool value) =>
      debugTestFallbackEnabled = value;

  @visibleForTesting
  static bool debugIsRunningInTests = Platform.environment.containsKey(
    'FLUTTER_TEST',
  );

  static String? _env(String key) {
    final override = _debugEnv;
    if (override != null) {
      final v = override[key];
      if (v != null && v.trim().isNotEmpty) return v.trim();
      if (override.containsKey(key)) return null;
    }
    if (dotenv.isInitialized) {
      final v = dotenv.maybeGet(key);
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static bool get _useDebugTestCredentials =>
      kDebugMode &&
      debugTestFallbackEnabled &&
      !debugIsRunningInTests &&
      _env('LEVELPLAY_DEBUG_USE_PRODUCTION')?.toLowerCase() != 'true';

  static bool get hasProductionConfig => _env('LEVELPLAY_APP_KEY') != null;

  static bool get usingTestCredentials =>
      _useDebugTestCredentials ||
      (!hasProductionConfig &&
          kDebugMode &&
          debugTestFallbackEnabled &&
          !debugIsRunningInTests);

  static String? get appKey => _useDebugTestCredentials
      ? _testAppKey
      : (_env('LEVELPLAY_APP_KEY') ??
          (kDebugMode && debugTestFallbackEnabled && !debugIsRunningInTests
              ? _testAppKey
              : null));

  static bool get isConfigured => appKey != null;

  static String? unitIdFor(String placement) {
    if (_useDebugTestCredentials) {
      switch (placement) {
        case LevelPlayPlacement.interstitialSessionBreak:
          return _testInterstitialUnit;
        case LevelPlayPlacement.rewardedFeature:
          return _testRewardedUnit;
        case LevelPlayPlacement.bannerHome:
          return _testBannerUnit;
      }
    }

    final key = unitEnvKeys[placement];
    if (key == null) return null;
    final primary = _env(key);
    if (primary != null) return primary;
    // Backward-compatible with the production unit used by the previously
    // working MREC build (#399-era configuration).
    if (placement == LevelPlayPlacement.bannerHome) {
      return _env('LEVELPLAY_UNIT_BANNER_HOME_01');
    }
    return null;
  }

  static bool unitConfigured(String placement) => unitIdFor(placement) != null;

  static int configuredUnitCount() {
    var n = 0;
    for (final p in unitEnvKeys.keys) {
      if (unitConfigured(p)) n++;
    }
    return n;
  }

  static bool get debugBuild => kDebugMode;
}

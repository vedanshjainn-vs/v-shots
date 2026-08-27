// ═════════════════════════════════════════════════════════════════════════
// V Shots — Unity LevelPlay Configuration (centralized)
//
// Credential model (Phase 6/7):
//   • LEVELPLAY_APP_KEY — the LevelPlay app key (client-safe; identifies the
//     app, not a person). Injected via CI secret → .env. Never printed in
//     full — diagnostics show CONFIGURED / MISSING only.
//   • LEVELPLAY_UNIT_* — per-format ad unit IDs (safe configuration values).
//   • Management/Report/Event API keys (if ever added) are SERVER-SIDE only
//     (dashboard automation), NEVER bundled into the app.
//
// Native ads: LevelPlay uses ONE native ad unit per app (resolved from the
// app key); V Shots stable placement names are passed per request for
// pacing/reporting.
//
// Debug builds intentionally use the official Unity LevelPlay TEST
// credentials even when CI also injects production credentials. This keeps
// the debug diagnostics deterministic and prevents a production unit's
// "Mediation No Fill" from being mistaken for an SDK integration failure.
// Release builds always use the configured production credentials.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Stable V Shots placement identifiers (Phase 8). These are V Shots
/// identifiers, NOT LevelPlay ad unit IDs — the mapping below keeps them
/// cleanly separated.
abstract class LevelPlayPlacement {
  static const String homeNative = 'HOME_NATIVE_01';
  static const String discoveryNative = 'DISCOVERY_NATIVE_01';
  static const String playerNative =
      'PLAYER_NATIVE_01'; // premium in-card player sponsored ad
  static const String libraryNative = 'LIBRARY_NATIVE_01';
  static const String searchNative = 'SEARCH_NATIVE_01';
  static const String interstitialSessionBreak =
      'INTERSTITIAL_SESSION_BREAK_01';
  static const String rewardedFeature = 'REWARDED_FEATURE_01';
  static const String bannerHome = 'BANNER_HOME_01';
}

class LevelPlayConfig {
  LevelPlayConfig._();

  /// Stable placement → env key for LevelPlay ad unit IDs.
  /// (Native placements have no per-placement unit — LevelPlay native is
  /// one unit per app; they map to placement NAMES instead.)
  static const Map<String, String> unitEnvKeys = {
    LevelPlayPlacement.interstitialSessionBreak:
        'LEVELPLAY_UNIT_INTERSTITIAL_SESSION_BREAK_01',
    LevelPlayPlacement.rewardedFeature: 'LEVELPLAY_UNIT_REWARDED_FEATURE_01',
    LevelPlayPlacement.bannerHome: 'LEVELPLAY_UNIT_BANNER_HOME_01',
  };

  // Official Unity LevelPlay TEST credentials (public in the official
  // ironsource-mobile/Flutter-SDK demo repository — for integration
  // verification only). Used by DEBUG builds so integration testing is
  // deterministic even when production secrets are present in CI.
  static const String _testAppKey = '25b63cf85';
  static const String _testInterstitialUnit = 'h3xw38h9214adgxo';
  static const String _testRewardedUnit = 'syz3d8ekts22q0or';
  static const String _testBannerUnit = '4fpetq4lhe5lsw3e';

  /// Test-only env override (unit tests).
  static Map<String, String>? _debugEnv;

  @visibleForTesting
  static void debugSetEnv(Map<String, String>? values) => _debugEnv = values;

  /// Test-only: disable the debug-build official-test-credentials fallback
  /// so tests can exercise the truly-unconfigured path deterministically.
  static bool debugTestFallbackEnabled = true;

  @visibleForTesting
  static void debugSetTestFallbackEnabled(bool value) =>
      debugTestFallbackEnabled = value;

  /// The test fallback must NEVER apply inside `flutter test` runs (the
  /// plugin channel is absent there); it only serves real debug builds.
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

  /// Debug builds use official test credentials by default. A developer can
  /// explicitly opt into production credentials for a debug build by setting
  /// LEVELPLAY_DEBUG_USE_PRODUCTION=true in the debug environment.
  static bool get _useDebugTestCredentials =>
      kDebugMode &&
      debugTestFallbackEnabled &&
      !debugIsRunningInTests &&
      _env('LEVELPLAY_DEBUG_USE_PRODUCTION')?.toLowerCase() != 'true';

  /// The production configuration is considered present independently of
  /// which credentials the current build chooses to use.
  static bool get hasProductionConfig => _env('LEVELPLAY_APP_KEY') != null;

  /// Whether the current build uses the official Unity TEST credentials.
  static bool get usingTestCredentials =>
      _useDebugTestCredentials ||
      (!hasProductionConfig &&
          kDebugMode &&
          debugTestFallbackEnabled &&
          !debugIsRunningInTests);

  /// The LevelPlay app key in effect.
  static String? get appKey => _useDebugTestCredentials
      ? _testAppKey
      : (_env('LEVELPLAY_APP_KEY') ??
            (kDebugMode && debugTestFallbackEnabled && !debugIsRunningInTests
                ? _testAppKey
                : null));

  /// Whether the advertising layer is configured at all.
  static bool get isConfigured => appKey != null;

  /// LevelPlay ad unit ID for a placement, or null when not configured.
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
    if (key == null) return null; // native placements: app-level unit
    return _env(key);
  }

  static bool unitConfigured(String placement) => unitIdFor(placement) != null;

  /// How many of the 3 unit-based placements are configured (diagnostics).
  static int configuredUnitCount() {
    var n = 0;
    for (final p in unitEnvKeys.keys) {
      if (unitConfigured(p)) n++;
    }
    return n;
  }

  static bool get debugBuild => kDebugMode;
}

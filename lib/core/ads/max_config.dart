// ═════════════════════════════════════════════════════════════════════════
// V Shots — AppLovin MAX Configuration (centralized)
//
// Credential model (Phase 4):
//   • APPLOVIN_MAX_SDK_KEY — the MAX app (SDK) key. Client-safe by design:
//     it identifies the app (not a person) and is the key the SDK needs at
//     init. Injected via CI secret → .env (bundled), never hard-coded.
//   • APPLOVIN_MAX_MANAGEMENT_KEY / APPLOVIN_MAX_REPORT_KEY /
//     APPLOVIN_MAX_EVENT_KEY — SERVER-SIDE credentials. They are NEVER
//     bundled into the app. Used only by scripts/max_setup.py (run locally
//     or in a CI server-side step with server env).
//
// Ad unit IDs are mapped from STABLE V Shots placement identifiers (Phase 6)
// so code, CI and the MAX dashboard never drift apart. A placement without a
// configured unit ID simply does not render (honest state, fail-safe).
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Stable V Shots placement identifiers (Phase 6).
abstract class MaxPlacement {
  static const String homeNative = 'HOME_NATIVE_01';
  static const String discoveryNative = 'DISCOVERY_NATIVE_01';
  static const String playerNative =
      'PLAYER_NATIVE_01'; // reserved — no player ads
  static const String libraryNative =
      'LIBRARY_NATIVE_01'; // library + playlist pages
  static const String searchNative = 'SEARCH_NATIVE_01';
  static const String interstitialSessionBreak =
      'INTERSTITIAL_SESSION_BREAK_01';
  static const String rewardedFeature = 'REWARDED_FEATURE_01';
  static const String bannerHome = 'BANNER_HOME_01'; // all in-flow banner slots
}

class MaxConfig {
  MaxConfig._();

  /// Stable placement → env key holding the MAX ad unit ID.
  static const Map<String, String> unitEnvKeys = {
    MaxPlacement.homeNative: 'APPLOVIN_MAX_UNIT_HOME_NATIVE_01',
    MaxPlacement.discoveryNative: 'APPLOVIN_MAX_UNIT_DISCOVERY_NATIVE_01',
    MaxPlacement.playerNative: 'APPLOVIN_MAX_UNIT_PLAYER_NATIVE_01',
    MaxPlacement.libraryNative: 'APPLOVIN_MAX_UNIT_LIBRARY_NATIVE_01',
    MaxPlacement.searchNative: 'APPLOVIN_MAX_UNIT_SEARCH_NATIVE_01',
    MaxPlacement.interstitialSessionBreak:
        'APPLOVIN_MAX_UNIT_INTERSTITIAL_SESSION_BREAK_01',
    MaxPlacement.rewardedFeature: 'APPLOVIN_MAX_UNIT_REWARDED_FEATURE_01',
    MaxPlacement.bannerHome: 'APPLOVIN_MAX_UNIT_BANNER_HOME_01',
  };

  /// Test-only env override (unit tests).
  static Map<String, String>? _debugEnv;

  @visibleForTesting
  static void debugSetEnv(Map<String, String>? values) => _debugEnv = values;

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

  /// MAX SDK (app) key. Null when not configured for this build.
  static String? get sdkKey => _env('APPLOVIN_MAX_SDK_KEY');

  /// Whether the MAX serving layer is configured at all (SDK key present).
  static bool get isConfigured => sdkKey != null;

  /// MAX ad unit ID for a stable placement, or null when not configured.
  static String? unitIdFor(String placement) {
    final key = unitEnvKeys[placement];
    if (key == null) return null;
    return _env(key);
  }

  static bool unitConfigured(String placement) => unitIdFor(placement) != null;

  /// How many of the 8 stable placements have unit IDs (diagnostics).
  static int configuredUnitCount() {
    var n = 0;
    for (final p in unitEnvKeys.keys) {
      if (unitConfigured(p)) n++;
    }
    return n;
  }

  static bool get debugBuild => kDebugMode;
}

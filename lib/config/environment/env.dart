// ════════════════════════════════════════════════
// Project Lyra — Environment Holder
// ════════════════════════════════════════════════
//
// Singleton that holds the active [EnvConfig].
// Set once at startup via --dart-define=FLAVOR=...
// ════════════════════════════════════════════════

import 'env_config.dart';
import 'flavors.dart';

/// Global environment accessor.
///
/// Set [Env.instance] once during app startup, then
/// access anywhere via `Env.instance`.
///
/// ```dart
/// final config = Env.instance;
/// print(config.apiBaseUrl);
/// ```
abstract final class Env {
  static late EnvConfig _instance;

  /// The current environment configuration.
  static EnvConfig get instance => _instance;

  /// Current flavor shortcut.
  static Flavor get flavor => _instance.flavor;

  /// Initialize from compile-time dart-define.
  ///
  /// Pass `--dart-define=FLAVOR=development` at build time.
  static void initialize({Flavor? flavor}) {
    const envFlavor = String.fromEnvironment(
      'FLAVOR',
      defaultValue: 'development',
    );

    final resolved = flavor ?? _parseFlavor(envFlavor);

    _instance = switch (resolved) {
      Flavor.development => EnvConfig.development,
      Flavor.staging => EnvConfig.staging,
      Flavor.production => EnvConfig.production,
    };
  }

  static Flavor _parseFlavor(String value) {
    return switch (value.toLowerCase()) {
      'production' || 'prod' => Flavor.production,
      'staging' || 'stg' => Flavor.staging,
      _ => Flavor.development,
    };
  }
}

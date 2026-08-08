// ════════════════════════════════════════════════
// Project Lyra — Build Flavors
// ════════════════════════════════════════════════
//
// Defines build environments for multi-flavor
// builds: development, staging, production.
// ════════════════════════════════════════════════

/// Supported build flavors / environments.
enum Flavor {
  development,
  staging,
  production;

  String get label => switch (this) {
        Flavor.development => 'DEV',
        Flavor.staging => 'STG',
        Flavor.production => 'PROD',
      };

  String get name => switch (this) {
        Flavor.development => 'Development',
        Flavor.staging => 'Staging',
        Flavor.production => 'Production',
      };

  bool get isProduction => this == Flavor.production;
  bool get isStaging => this == Flavor.staging;
  bool get isDevelopment => this == Flavor.development;

  /// Whether debug features should be enabled.
  bool get enableDebug => !isProduction;

  /// Whether to show the debug banner.
  bool get showDebugBanner => isDevelopment;
}

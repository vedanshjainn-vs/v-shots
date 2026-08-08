// ════════════════════════════════════════════════
// Project Lyra — App Scope
// ════════════════════════════════════════════════
//
// Riverpod overrides for app-wide providers.
// Used at the ProviderScope level in main.dart.
// ════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Creates provider overrides for the app's top-level scope.
///
/// Use this in [ProviderScope.overrides] to inject
/// environment-specific implementations.
///
/// ```dart
/// runApp(
///   ProviderScope(
///     overrides: AppScope.overrides(flavor: Flavor.production),
///     child: const LyraApp(),
///   ),
/// );
/// ```
abstract final class AppScope {
  static List<Override> overrides({
    // TODO(team): Add flavor-specific overrides here.
    // Example:
    // required Flavor flavor,
    // required EnvConfig config,
  }) {
    return [
      // Override providers that vary by environment.
      // Example:
      // envConfigProvider.overrideWithValue(config),
      // analyticsServiceProvider.overrideWith((ref) => ...),
    ];
  }
}

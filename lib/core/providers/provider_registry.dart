// ════════════════════════════════════════════════
// V Shots — Provider Architecture: registry
// ════════════════════════════════════════════════
//
// Holds the set of providers the app knows about and the configured
// priority order. Deliberately separate from ProviderManager (which
// owns routing/health/failover behavior) — the registry's only job is
// "what providers exist and in what order," matching
// PROVIDER_ARCHITECTURE.md's own component table
// (`ProviderRegistry` = "Manages provider registration and lifecycle").
// ════════════════════════════════════════════════

import 'music_provider.dart';
import 'provider_config.dart';

class ProviderRegistry {
  ProviderRegistry();

  final Map<String, MusicProvider> _providers = {};

  /// Registers [provider] under its own `id`. Safe to call multiple
  /// times for the same id (replaces the previous registration) — used
  /// by tests that swap in a fake provider.
  void register(MusicProvider provider) {
    _providers[provider.id] = provider;
  }

  MusicProvider? operator [](String id) => _providers[id];

  bool get isEmpty => _providers.isEmpty;
  bool get isNotEmpty => _providers.isNotEmpty;

  List<MusicProvider> get all => List.unmodifiable(_providers.values);

  /// Returns registered providers in [config]'s priority order,
  /// skipping any priority entries that aren't actually registered
  /// (e.g. a future provider listed in config but not yet
  /// implemented/registered).
  List<MusicProvider> inPriorityOrder(ProviderConfig config) {
    final ordered = <MusicProvider>[];
    for (final id in config.providerPriority) {
      final p = _providers[id];
      if (p != null && config.enabledProviders.contains(id)) {
        ordered.add(p);
      }
    }
    return ordered;
  }
}

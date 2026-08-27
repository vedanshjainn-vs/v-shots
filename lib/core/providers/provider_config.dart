// ════════════════════════════════════════════════
// V Shots — Provider Architecture: configuration
// ════════════════════════════════════════════════
//
// Per the task's Phase 6 ("Remote Config Ready"): this shape is
// designed so a future remote config source (e.g. a Supabase table row
// or a simple JSON file fetched at startup) can populate it WITHOUT
// changing ProviderManager/ProviderRegistry's code — only how a
// `ProviderConfig` gets constructed would change.
//
// ⚠️ HONEST SCOPE NOTE (do not overstate this): right now this is
// LOCAL, HARDCODED configuration only (`ProviderConfig.defaultConfig`).
// There is NO remote-config mechanism actually wired up — no network
// call fetches this, no Supabase table backs it. Claiming "remote
// provider switching works" would be false; this file only makes sure
// the *shape* of the config won't need to change when that's built
// later, exactly as the task instructions asked for ("this may use
// local configuration... DO NOT claim remote provider switching works
// unless an actual remote-config mechanism is implemented").
// ════════════════════════════════════════════════

class ProviderConfig {
  const ProviderConfig({
    required this.activeProvider,
    required this.enabledProviders,
    required this.providerPriority,
  });

  /// The provider ProviderManager should route requests to first.
  final String activeProvider;

  /// Providers allowed to be used at all (a provider can be registered
  /// but disabled here without removing its code).
  final List<String> enabledProviders;

  /// Fallback order if [activeProvider] fails a health check —
  /// [activeProvider] should normally be first in this list.
  final List<String> providerPriority;

  /// InnerTube is the PRIMARY discovery provider (live, real YouTube
  /// catalog); the official YouTube Data API v3 provider is the fallback
  /// (itself backed by a curated catalog when no API key is configured).
  /// ProviderManager routes every search through this priority order with
  /// automatic failover.
  static const defaultConfig = ProviderConfig(
    activeProvider: 'innertube',
    enabledProviders: ['innertube', 'youtube'],
    providerPriority: ['innertube', 'youtube'],
  );

  Map<String, dynamic> toJson() => {
    'activeProvider': activeProvider,
    'enabledProviders': enabledProviders,
    'providerPriority': providerPriority,
  };

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    return ProviderConfig(
      activeProvider: json['activeProvider'] as String? ?? 'innertube',
      enabledProviders:
          (json['enabledProviders'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const ['innertube', 'youtube'],
      providerPriority:
          (json['providerPriority'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const ['innertube', 'youtube'],
    );
  }
}

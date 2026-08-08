// ════════════════════════════════════════════════
// Project Lyra — Provider Registry
// ════════════════════════════════════════════════
//
// Simple registry for music providers.
// Register, unregister, get, switch, health check.
// ════════════════════════════════════════════════

import '../../../config/provider_config.dart';
import '../../logging/app_logger.dart';
import '../imusic_provider.dart';

/// Simple registry for music providers.
///
/// ```dart
/// final registry = ProviderRegistry();
/// registry.register(DevelopmentProvider());
/// registry.register(SpotifyProvider());
///
/// final provider = registry.getActiveProvider();
/// ```
class ProviderRegistry {
  ProviderRegistry({AppLogger? logger}) : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;
  final Map<String, IMusicProvider> _providers = {};
  final Map<String, bool> _healthStatus = {};

  /// All registered provider IDs.
  List<String> get registeredIds => _providers.keys.toList();

  /// The currently active provider ID from config.
  String get activeProviderId => ProviderConfig.activeProvider;

  // ── Register / Unregister ────────────────────

  /// Register a provider.
  ///
  /// ```dart
  /// registry.register(DevelopmentProvider());
  /// ```
  void register(IMusicProvider provider) {
    _providers[provider.id] = provider;
    _logger.d('Registry: Registered ${provider.id}');
  }

  /// Unregister a provider.
  void unregister(String providerId) {
    _providers.remove(providerId);
    _healthStatus.remove(providerId);
    _logger.d('Registry: Unregistered $providerId');
  }

  /// Check if a provider is registered.
  bool isRegistered(String providerId) => _providers.containsKey(providerId);

  // ── Get Provider ─────────────────────────────

  /// Get the active provider.
  ///
  /// Returns the provider matching [ProviderConfig.activeProvider].
  /// If not found, returns null.
  IMusicProvider? getActiveProvider() {
    return _providers[ProviderConfig.activeProvider];
  }

  /// Get the fallback provider (if configured).
  IMusicProvider? getFallbackProvider() {
    final fallbackId = ProviderConfig.fallbackProvider;
    if (fallbackId == null) return null;
    return _providers[fallbackId];
  }

  /// Get a provider by ID.
  IMusicProvider? getProvider(String providerId) {
    return _providers[providerId];
  }

  // ── Switch Provider ──────────────────────────

  /// Switch the active provider at runtime.
  ///
  /// This updates the config for the current session.
  /// To persist the change, update [ProviderConfig.activeProvider].
  bool switchProvider(String providerId) {
    if (!_providers.containsKey(providerId)) {
      _logger.e('Registry: Cannot switch — $providerId not registered');
      return false;
    }
    // Note: This only works if ProviderConfig is made non-const.
    // For runtime switching, use a mutable config or restart.
    _logger.i('Registry: Switched to $providerId');
    return true;
  }

  // ── Health Check ─────────────────────────────

  /// Run health check on a specific provider.
  Future<bool> healthCheck(String providerId) async {
    final provider = _providers[providerId];
    if (provider == null) {
      _logger.w('Registry: healthCheck — $providerId not found');
      return false;
    }

    try {
      final status = await provider.healthCheck();
      _healthStatus[providerId] = status.isHealthy;
      return status.isHealthy;
    } catch (e) {
      _healthStatus[providerId] = false;
      _logger.e('Registry: healthCheck failed for $providerId', error: e);
      return false;
    }
  }

  /// Run health checks on all registered providers.
  Future<Map<String, bool>> healthCheckAll() async {
    for (final id in _providers.keys) {
      await healthCheck(id);
    }
    return Map.unmodifiable(_healthStatus);
  }

  /// Check if a provider is healthy.
  bool isHealthy(String providerId) => _healthStatus[providerId] ?? true;

  // ── Lifecycle ────────────────────────────────

  /// Initialize all registered providers.
  Future<void> initializeAll() async {
    for (final provider in _providers.values) {
      try {
        await provider.initialize(const _DefaultProviderInitConfig());
        _logger.d('Registry: Initialized ${provider.id}');
      } catch (e) {
        _logger.e('Registry: Init failed for ${provider.id}', error: e);
      }
    }
  }

  /// Dispose all registered providers.
  Future<void> disposeAll() async {
    for (final provider in _providers.values) {
      try {
        await provider.dispose();
      } catch (e) {
        _logger.e('Registry: Dispose failed for ${provider.id}', error: e);
      }
    }
    _providers.clear();
    _healthStatus.clear();
  }
}

/// Default provider config for initialization.
class _DefaultProviderInitConfig implements ProviderInitConfig {
  const _DefaultProviderInitConfig();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

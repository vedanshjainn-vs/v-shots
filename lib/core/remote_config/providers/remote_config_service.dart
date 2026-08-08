// ════════════════════════════════════════════════
// Project Lyra — Remote Config Service
// ════════════════════════════════════════════════
//
// Remote configuration that integrates with
// the existing feature flag system. Fetches
// config from server and caches locally.
// ════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';

import '../../feature_flags/models/feature_flag.dart';
import '../../feature_flags/providers/feature_flag_service.dart';
import '../../logging/app_logger.dart';
import '../../storage/local_storage.dart';

/// Service for fetching and managing remote configuration.
///
/// Integrates with [FeatureFlagService] to provide
/// server-controlled feature flags, A/B tests, and kill switches.
///
/// ```dart
/// final remoteConfig = RemoteConfigService(
///   featureFlagService: featureFlags,
///   storage: localStorage,
/// );
/// await remoteConfig.initialize();
/// await remoteConfig.refresh();
/// ```
class RemoteConfigService {
  RemoteConfigService({
    required this.featureFlagService,
    required this.storage,
    this.refreshInterval = const Duration(minutes: 15),
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final FeatureFlagService featureFlagService;
  final LocalStorage storage;
  final Duration refreshInterval;
  final AppLogger _logger;

  Timer? _refreshTimer;
  DateTime? _lastFetchTime;
  bool _isInitialized = false;

  /// Storage keys.
  static const String _configKey = 'remote_config_cache';
  static const String _flagsKey = 'remote_flags_cache';

  /// Initialize the remote config service.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load cached config.
    await _loadCachedConfig();

    // Start periodic refresh.
    _refreshTimer = Timer.periodic(refreshInterval, (_) => refresh());

    _isInitialized = true;
    _logger.d('RemoteConfigService: Initialized');
  }

  /// Fetch latest config from server.
  Future<bool> refresh() async {
    try {
      _logger.d('RemoteConfigService: Refreshing...');

      // TODO(team): Fetch from Supabase or Firebase Remote Config.
      // final response = await supabase.from('remote_config').select();
      // final flags = response.map((r) => FeatureFlag.fromJson(r)).toList();

      // For now, use cached values.
      _lastFetchTime = DateTime.now();

      // Persist to local storage.
      await _persistConfig();

      _logger.d('RemoteConfigService: Refreshed successfully');
      return true;
    } catch (e, st) {
      _logger.e('RemoteConfigService: Refresh failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Update feature flags from server data.
  void updateFlags(Map<String, dynamic> flags) {
    featureFlagService.updateRemoteValues(flags);
    _persistConfig();
  }

  /// Get the last fetch time.
  DateTime? get lastFetchTime => _lastFetchTime;

  /// Whether the config needs refresh.
  bool get needsRefresh {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > refreshInterval;
  }

  Future<void> _loadCachedConfig() async {
    try {
      final cached = await storage.getString(_flagsKey);
      if (cached != null) {
        final flags = jsonDecode(cached) as Map<String, dynamic>;
        featureFlagService.updateRemoteValues(flags);
        _logger.d('RemoteConfigService: Loaded ${flags.length} cached flags');
      }
    } catch (e) {
      _logger.w('RemoteConfigService: Failed to load cached config');
    }
  }

  Future<void> _persistConfig() async {
    try {
      // TODO(team): Serialize current remote values.
      // await storage.setString(_flagsKey, jsonEncode(remoteValues));
    } catch (e) {
      _logger.w('RemoteConfigService: Failed to persist config');
    }
  }

  /// Dispose resources.
  void dispose() {
    _refreshTimer?.cancel();
  }
}

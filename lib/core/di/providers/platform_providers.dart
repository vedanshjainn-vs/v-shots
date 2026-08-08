// ════════════════════════════════════════════════
// Project Lyra — Platform Service Providers
// ════════════════════════════════════════════════
//
// Riverpod providers for all new platform services.
// Lazily initialized for fast cold start.
// ════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/batching/analytics_batcher.dart';
import '../../cache/cache_manager.dart';
import '../../cache/disk/disk_cache.dart';
import '../../cache/memory/memory_cache.dart';
import '../../cache/serialization/cache_serializer.dart';
import '../../connectivity/monitors/connectivity_monitor.dart';
import '../../events/bus/app_event_bus.dart';
import '../../feature_flags/providers/feature_flag_service.dart';
import '../../media/sleep_timer/sleep_timer_service.dart';
import '../../navigation/deep_links/deep_link_handler.dart';
import '../../navigation/guards/premium_guard.dart';
import '../../network/circuit_breaker/circuit_breaker.dart';
import '../../network/deduplication/request_deduplicator.dart';
import '../../performance/startup_optimizer.dart';
import '../../remote_config/providers/remote_config_service.dart';
import '../../security/biometric/biometric_service.dart';
import '../../security/crypto/encryption_service.dart';
import '../../security/storage/secure_storage_service.dart';
import '../../security/storage/token_manager.dart';
import '../../telemetry/monitors/performance_monitor.dart';

// ── Event Bus ─────────────────────────────────

/// Global application event bus.
final appEventBusProvider = Provider<AppEventBus>((ref) {
  final bus = AppEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});

// ── Connectivity ──────────────────────────────

/// Connectivity monitor with event bus integration.
final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  final monitor = ConnectivityMonitor(
    eventBus: ref.watch(appEventBusProvider),
  );
  ref.onDispose(monitor.dispose);
  return monitor;
});

// ── Cache System ──────────────────────────────

/// Cache serializer.
final cacheSerializerProvider = Provider<CacheSerializer>((ref) {
  return CacheSerializer();
});

/// Memory cache for API responses.
final memoryCacheProvider = Provider<MemoryCache<String>>((ref) {
  return MemoryCache<String>(maxSize: 500);
});

/// Disk cache for API responses.
final diskCacheProvider = FutureProvider<DiskCache>((ref) async {
  return DiskCache.open('api_cache', maxEntries: 2000);
});

/// Cache manager orchestrator.
final cacheManagerProvider = FutureProvider<CacheManager>((ref) async {
  final memory = ref.watch(memoryCacheProvider);
  final disk = await ref.watch(diskCacheProvider.future);
  final serializer = ref.watch(cacheSerializerProvider);

  return CacheManager(
    memory: memory,
    disk: disk,
    serializer: serializer,
  );
});

// ── Security ──────────────────────────────────

/// Secure storage service.
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Token manager.
final tokenManagerProvider = Provider<TokenManager>((ref) {
  return TokenManager(
    secureStorage: ref.watch(secureStorageProvider),
  );
});

/// Biometric service.
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

/// Encryption service.
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

// ── Network ───────────────────────────────────

/// Circuit breaker for API calls.
final circuitBreakerProvider = Provider<CircuitBreaker>((ref) {
  return CircuitBreaker(
    name: 'api',
    config: const CircuitBreakerConfig(
      failureThreshold: 5,
      timeout: Duration(seconds: 30),
    ),
  );
});

/// Request deduplicator.
final requestDeduplicatorProvider = Provider<RequestDeduplicator>((ref) {
  return RequestDeduplicator();
});

// ── Feature Flags ─────────────────────────────

/// Feature flag service.
final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  return FeatureFlagService();
});

/// Remote config service.
final remoteConfigServiceProvider = FutureProvider<RemoteConfigService>((ref) async {
  return RemoteConfigService(
    featureFlagService: ref.watch(featureFlagServiceProvider),
    storage: ref.watch(settingsStorageProvider).value!,
  );
});

// Import needed for settingsStorageProvider.
import 'storage_providers.dart';

// ── Analytics ─────────────────────────────────

/// Analytics batcher.
final analyticsBatcherProvider = Provider<AnalyticsBatcher>((ref) {
  final batcher = AnalyticsBatcher(
    onFlush: (events) async {
      // TODO(team): Send batched events to analytics provider.
    },
  );
  ref.onDispose(batcher.dispose);
  return batcher;
});

// ── Telemetry ─────────────────────────────────

/// Performance monitor.
final performanceMonitorProvider = Provider<PerformanceMonitor>((ref) {
  return PerformanceMonitor();
});

/// Startup optimizer.
final startupOptimizerProvider = Provider<StartupOptimizer>((ref) {
  return StartupOptimizer(
    performanceMonitor: ref.watch(performanceMonitorProvider),
  );
});

// ── Navigation ────────────────────────────────

/// Deep link handler.
final deepLinkHandlerProvider = Provider<DeepLinkHandler>((ref) {
  return DeepLinkHandler();
});

/// Premium guard.
final premiumGuardProvider = Provider<PremiumGuard>((ref) {
  return PremiumGuard(
    getCurrentTier: () {
      // TODO(team): Read from user state provider.
      return SubscriptionTier.free;
    },
  );
});

// Import needed.
import '../../enums/subscription_tier.dart';

// ── Media ─────────────────────────────────────

/// Sleep timer service.
final sleepTimerServiceProvider = Provider<SleepTimerService>((ref) {
  final service = SleepTimerService();
  ref.onDispose(service.dispose);
  return service;
});

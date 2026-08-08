// ════════════════════════════════════════════════
// Project Lyra — Riverpod Provider Observer
// ════════════════════════════════════════════════
//
// Logs provider lifecycle events for debugging.
// In production, feeds into analytics / crashlytics.
// ════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';

/// Observes all Riverpod provider state changes.
///
/// Wire this into [ProviderScope.observers] during app init.
class AppProviderObserver extends ProviderObserver {
  AppProviderObserver({AppLogger? logger}) : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    if (kDebugMode) {
      _logger.d('Provider added: ${provider.name ?? provider.runtimeType}');
    }
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (kDebugMode) {
      _logger.d(
        'Provider updated: ${provider.name ?? provider.runtimeType}',
      );
    }
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    if (kDebugMode) {
      _logger.d('Provider disposed: ${provider.name ?? provider.runtimeType}');
    }
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    _logger.e(
      'Provider failed: ${provider.name ?? provider.runtimeType}',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

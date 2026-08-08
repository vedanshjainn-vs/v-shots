// ════════════════════════════════════════════════
// Project Lyra — Scope Definitions
// ════════════════════════════════════════════════
//
// Defines provider scopes for different lifetimes:
// - App: lives for the entire app lifetime
// - Session: lives for a user session (login → logout)
// - Feature: lives while a feature screen is open
// - Transient: new instance every time
// ════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider lifetime scopes.
enum ProviderScope {
  /// Lives for the entire app lifetime.
  /// Never disposed. Use for: config, logger, storage.
  app,

  /// Lives for a user session (login → logout).
  /// Disposed on logout. Use for: auth, user profile, token.
  session,

  /// Lives while a feature screen is open.
  /// Disposed on navigation away. Use for: feature state.
  feature,

  /// New instance created every time it's read.
  /// Use for: one-shot operations, formatters.
  transient,
}

/// Extension for creating scoped providers.
extension ScopedProvider on ProviderContainer {
  /// Dispose all session-scoped providers.
  void disposeSession() {
    // TODO(team): Implement session-scoped provider disposal.
    // This requires tracking which providers are session-scoped.
  }

  /// Dispose all feature-scoped providers.
  void disposeFeature(String featureName) {
    // TODO(team): Implement feature-scoped provider disposal.
  }
}

/// Provider that auto-disposes when not listened to.
///
/// Use for feature-scoped state that should be cleaned up
/// when the user navigates away.
final autoDisposeProvider = Provider.autoDispose<String>((ref) {
  ref.onDispose(() {
    // Cleanup logic.
  });
  return 'auto_dispose_value';
});

/// Provider that persists across the app lifetime.
///
/// Use for infrastructure: logger, storage, config.
final appScopedProvider = Provider<String>((ref) {
  // Never auto-disposed.
  return 'app_scoped_value';
});

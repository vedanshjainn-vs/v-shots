// ════════════════════════════════════════════════
// Project Lyra — Analytics Service
// ════════════════════════════════════════════════
//
// Abstraction over Firebase Analytics.
// Features depend on this interface, not Firebase directly.
// ════════════════════════════════════════════════

/// Analytics service interface.
///
/// Implementations: [FirebaseAnalyticsService].
/// Injected via Riverpod for testability.
abstract class AnalyticsService {
  /// Log a custom event.
  Future<void> logEvent(String name, {Map<String, dynamic>? parameters});

  /// Set the current user ID.
  Future<void> setUserId(String? userId);

  /// Set a user property.
  Future<void> setUserProperty(String name, String? value);

  /// Log a screen view.
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  });

  /// Log a search event.
  Future<void> logSearch({required String query});

  /// Log a content selection.
  Future<void> logSelectContent({
    required String contentType,
    required String itemId,
  });

  /// Log a purchase event (for premium).
  Future<void> logPurchase({
    required String itemId,
    required double value,
    required String currency,
  });

  /// Enable or disable analytics collection.
  Future<void> setEnabled(bool enabled);
}

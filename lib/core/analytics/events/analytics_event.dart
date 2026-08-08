// ════════════════════════════════════════════════
// Project Lyra — Analytics Event Model
// ════════════════════════════════════════════════
//
// Typed analytics events with properties.
// Prevents typos and ensures consistency.
// ════════════════════════════════════════════════

/// A typed analytics event with properties.
class AnalyticsEvent {
  const AnalyticsEvent({
    required this.name,
    this.properties = const {},
    this.timestamp,
  });

  /// Event name (e.g., 'track_played').
  final String name;

  /// Event properties.
  final Map<String, dynamic> properties;

  /// When the event occurred.
  final DateTime? timestamp;

  /// Create with additional properties.
  AnalyticsEvent withProperties(Map<String, dynamic> extra) {
    return AnalyticsEvent(
      name: name,
      properties: {...properties, ...extra},
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'event': name,
        'properties': properties,
        'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
      };
}

/// Well-known analytics event definitions.
abstract final class LyraAnalyticsEvents {
  // ── Lifecycle ────────────────────────────────
  static const AnalyticsEvent appOpen = AnalyticsEvent(name: 'app_open');
  static const AnalyticsEvent appBackground = AnalyticsEvent(name: 'app_background');
  static const AnalyticsEvent appForeground = AnalyticsEvent(name: 'app_foreground');

  // ── Auth ─────────────────────────────────────
  static AnalyticsEvent login(String method) =>
      AnalyticsEvent(name: 'login', properties: {'method': method});
  static AnalyticsEvent signUp(String method) =>
      AnalyticsEvent(name: 'sign_up', properties: {'method': method});
  static const AnalyticsEvent logout = AnalyticsEvent(name: 'logout');

  // ── Playback ─────────────────────────────────
  static AnalyticsEvent playTrack(String trackId, {String? source}) =>
      AnalyticsEvent(name: 'play_track', properties: {
        'track_id': trackId,
        if (source != null) 'source': source,
      });
  static AnalyticsEvent pauseTrack(String trackId) =>
      AnalyticsEvent(name: 'pause_track', properties: {'track_id': trackId});
  static AnalyticsEvent skipTrack(String trackId, {String direction = 'next'}) =>
      AnalyticsEvent(name: 'skip_track', properties: {
        'track_id': trackId,
        'direction': direction,
      });

  // ── Search ───────────────────────────────────
  static AnalyticsEvent search(String query, {int? resultCount}) =>
      AnalyticsEvent(name: 'search', properties: {
        'query': query,
        if (resultCount != null) 'result_count': resultCount,
      });
  static AnalyticsEvent aiSearch(String query) =>
      AnalyticsEvent(name: 'ai_search', properties: {'query': query});

  // ── Library ──────────────────────────────────
  static AnalyticsEvent likeTrack(String trackId) =>
      AnalyticsEvent(name: 'like_track', properties: {'track_id': trackId});
  static AnalyticsEvent saveContent(String contentType, String contentId) =>
      AnalyticsEvent(name: 'save_content', properties: {
        'content_type': contentType,
        'content_id': contentId,
      });
  static AnalyticsEvent createPlaylist(String playlistId) =>
      AnalyticsEvent(name: 'create_playlist', properties: {'playlist_id': playlistId});

  // ── Premium ──────────────────────────────────
  static AnalyticsEvent viewPremiumPlans() =>
      const AnalyticsEvent(name: 'view_premium_plans');
  static AnalyticsEvent subscribePremium(String plan) =>
      AnalyticsEvent(name: 'subscribe_premium', properties: {'plan': plan});

  // ── Downloads ────────────────────────────────
  static AnalyticsEvent startDownload(String contentId) =>
      AnalyticsEvent(name: 'start_download', properties: {'content_id': contentId});
  static AnalyticsEvent completeDownload(String contentId) =>
      AnalyticsEvent(name: 'complete_download', properties: {'content_id': contentId});

  // ── Errors ───────────────────────────────────
  static AnalyticsEvent error(String errorType, {String? message}) =>
      AnalyticsEvent(name: 'error', properties: {
        'error_type': errorType,
        if (message != null) 'message': message,
      });

  // ── Screen Views ─────────────────────────────
  static AnalyticsEvent screenView(String screenName) =>
      AnalyticsEvent(name: 'screen_view', properties: {'screen_name': screenName});
}

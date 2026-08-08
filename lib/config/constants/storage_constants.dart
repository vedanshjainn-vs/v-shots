// ════════════════════════════════════════════════
// Project Lyra — Storage Constants
// ════════════════════════════════════════════════
//
// Keys for Hive boxes, SharedPreferences, and
// any local persistence layer.
// ════════════════════════════════════════════════

/// Storage keys and box names for local persistence.
abstract final class StorageConstants {
  // ── Hive Box Names ───────────────────────────
  static const String userBox = 'user_box';
  static const String settingsBox = 'settings_box';
  static const String cacheBox = 'cache_box';
  static const String playlistBox = 'playlist_box';
  static const String downloadBox = 'download_box';
  static const String searchHistoryBox = 'search_history_box';
  static const String playbackBox = 'playback_box';
  static const String queueBox = 'queue_box';
  static const String analyticsBox = 'analytics_box';

  // ── SharedPreferences Keys ───────────────────
  // Auth
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyIsLoggedIn = 'is_logged_in';

  // Onboarding
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyFirstLaunch = 'first_launch';

  // Settings
  static const String keyThemeMode = 'theme_mode';
  static const String keyLocale = 'locale';
  static const String keyAudioQuality = 'audio_quality';
  static const String keyDownloadOverWifiOnly = 'download_over_wifi_only';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyAnalyticsEnabled = 'analytics_enabled';
  static const String keyCrossfadeEnabled = 'crossfade_enabled';
  static const String keyGaplessPlayback = 'gapless_playback';
  static const String keyNormalizeVolume = 'normalize_volume';
  static const String keyExplicitContent = 'explicit_content';

  // Playback
  static const String keyLastPlayedTrack = 'last_played_track';
  static const String keyLastPlayedPosition = 'last_played_position';
  static const String keyLastPlayedQueue = 'last_played_queue';
  static const String keyRepeatMode = 'repeat_mode';
  static const String keyShuffleEnabled = 'shuffle_enabled';

  // Cache
  static const String keyLastSyncTimestamp = 'last_sync_timestamp';
  static const String keyCacheVersion = 'cache_version';

  // ── Cache Versioning ─────────────────────────
  // Bump this when cache schema changes to force clear.
  static const int currentCacheVersion = 1;
}

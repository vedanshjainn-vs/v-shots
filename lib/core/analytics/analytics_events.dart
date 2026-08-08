// ════════════════════════════════════════════════
// Project Lyra — Analytics Events
// ════════════════════════════════════════════════
//
// Centralized analytics event names and parameters.
// Prevents typos and ensures consistency.
// ════════════════════════════════════════════════

/// Standard analytics event names.
abstract final class AnalyticsEvents {
  // ── Lifecycle ────────────────────────────────
  static const String appOpen = 'app_open';
  static const String appClose = 'app_close';

  // ── Auth ─────────────────────────────────────
  static const String login = 'login';
  static const String signUp = 'sign_up';
  static const String logout = 'logout';
  static const String loginMethod = 'login_method';

  // ── Playback ─────────────────────────────────
  static const String playTrack = 'play_track';
  static const String pauseTrack = 'pause_track';
  static const String skipTrack = 'skip_track';
  static const String seekTrack = 'seek_track';
  static const String completeTrack = 'complete_track';
  static const String repeatModeChanged = 'repeat_mode_changed';
  static const String shuffleToggled = 'shuffle_toggled';
  static const String queueModified = 'queue_modified';

  // ── Content ──────────────────────────────────
  static const String viewAlbum = 'view_album';
  static const String viewArtist = 'view_artist';
  static const String viewPlaylist = 'view_playlist';
  static const String viewPodcast = 'view_podcast';
  static const String viewAudiobook = 'view_audiobook';

  // ── Library ──────────────────────────────────
  static const String likeTrack = 'like_track';
  static const String unlikeTrack = 'unlike_track';
  static const String saveAlbum = 'save_album';
  static const String savePlaylist = 'save_playlist';
  static const String followArtist = 'follow_artist';
  static const String unfollowArtist = 'unfollow_artist';
  static const String createPlaylist = 'create_playlist';

  // ── Search ───────────────────────────────────
  static const String search = 'search';
  static const String searchResultTap = 'search_result_tap';
  static const String aiSearchUsed = 'ai_search_used';

  // ── Downloads ────────────────────────────────
  static const String downloadStart = 'download_start';
  static const String downloadComplete = 'download_complete';
  static const String downloadDelete = 'download_delete';

  // ── Premium ──────────────────────────────────
  static const String premiumViewPlans = 'premium_view_plans';
  static const String premiumSubscribe = 'premium_subscribe';
  static const String premiumRestore = 'premium_restore';

  // ── AI Features ──────────────────────────────
  static const String aiDJStart = 'ai_dj_start';
  static const String aiRecommendationTap = 'ai_recommendation_tap';
}

/// Standard analytics parameter keys.
abstract final class AnalyticsParams {
  static const String trackId = 'track_id';
  static const String trackName = 'track_name';
  static const String artistId = 'artist_id';
  static const String artistName = 'artist_name';
  static const String albumId = 'album_id';
  static const String albumName = 'album_name';
  static const String playlistId = 'playlist_id';
  static const String podcastId = 'podcast_id';
  static const String source = 'source';
  static const String method = 'method';
  static const String query = 'query';
  static const String resultCount = 'result_count';
  static const String position = 'position';
  static const String duration = 'duration';
  static const String value = 'value';
  static const String currency = 'currency';
  static const String error = 'error';
}

// ════════════════════════════════════════════════
// Project Lyra — API Endpoints
// ════════════════════════════════════════════════
//
// Type-safe endpoint builder with path parameters
// and query string support.
// ════════════════════════════════════════════════

/// Builds API endpoint URLs with path parameters.
///
/// ```dart
/// final url = Endpoints.track('abc123');
/// // → '/api/v1/tracks/abc123'
/// ```
abstract final class Endpoints {
  static const String _base = '/api/v1';

  // ── Auth ─────────────────────────────────────
  static const String login = '$_base/auth/login';
  static const String register = '$_base/auth/register';
  static const String refreshToken = '$_base/auth/refresh';
  static const String logout = '$_base/auth/logout';
  static const String googleSignIn = '$_base/auth/google';
  static const String forgotPassword = '$_base/auth/forgot-password';

  // ── User ─────────────────────────────────────
  static const String profile = '$_base/user/profile';
  static String updateProfile(String userId) => '$_base/user/$userId';
  static const String preferences = '$_base/user/preferences';
  static const String subscription = '$_base/user/subscription';

  // ── Tracks ───────────────────────────────────
  static const String tracks = '$_base/tracks';
  static String track(String id) => '$_base/tracks/$id';
  static String trackStream(String id) => '$_base/tracks/$id/stream';
  static String trackLyrics(String id) => '$_base/tracks/$id/lyrics';

  // ── Albums ───────────────────────────────────
  static const String albums = '$_base/albums';
  static String album(String id) => '$_base/albums/$id';
  static String albumTracks(String id) => '$_base/albums/$id/tracks';

  // ── Artists ──────────────────────────────────
  static const String artists = '$_base/artists';
  static String artist(String id) => '$_base/artists/$id';
  static String artistAlbums(String id) => '$_base/artists/$id/albums';
  static String artistTopTracks(String id) => '$_base/artists/$id/top-tracks';
  static String artistRelated(String id) => '$_base/artists/$id/related';
  static String followArtist(String id) => '$_base/artists/$id/follow';

  // ── Playlists ────────────────────────────────
  static const String playlists = '$_base/playlists';
  static String playlist(String id) => '$_base/playlists/$id';
  static String playlistTracks(String id) => '$_base/playlists/$id/tracks';
  static String playlistAddTrack(String id) => '$_base/playlists/$id/tracks';
  static String playlistRemoveTrack(String playlistId, String trackId) =>
      '$_base/playlists/$playlistId/tracks/$trackId';
  static String followPlaylist(String id) => '$_base/playlists/$id/follow';

  // ── Search ───────────────────────────────────
  static const String search = '$_base/search';
  static const String searchSuggestions = '$_base/search/suggestions';
  static const String aiSearch = '$_base/ai/search';

  // ── Recommendations ──────────────────────────
  static const String recommendations = '$_base/recommendations';
  static const String aiRecommendations = '$_base/ai/recommendations';
  static const String aiDJ = '$_base/ai/dj';
  static const String trending = '$_base/trending';
  static const String newReleases = '$_base/new-releases';
  static const String forYou = '$_base/for-you';

  // ── Podcasts ─────────────────────────────────
  static const String podcasts = '$_base/podcasts';
  static String podcast(String id) => '$_base/podcasts/$id';
  static String podcastEpisodes(String id) => '$_base/podcasts/$id/episodes';
  static String episode(String id) => '$_base/episodes/$id';

  // ── Audiobooks ───────────────────────────────
  static const String audiobooks = '$_base/audiobooks';
  static String audiobook(String id) => '$_base/audiobooks/$id';
  static String audiobookChapters(String id) => '$_base/audiobooks/$id/chapters';

  // ── Library ──────────────────────────────────
  static const String library = '$_base/library';
  static const String likedSongs = '$_base/library/liked-songs';
  static const String savedAlbums = '$_base/library/albums';
  static const String savedPlaylists = '$_base/library/playlists';
  static const String savedArtists = '$_base/library/artists';
  static const String savedPodcasts = '$_base/library/podcasts';
  static const String savedAudiobooks = '$_base/library/audiobooks';
  static const String recentHistory = '$_base/library/history';
  static String like(String type, String id) => '$_base/library/$type/$id/like';
  static String unlike(String type, String id) => '$_base/library/$type/$id/unlike';

  // ── Downloads ────────────────────────────────
  static const String downloads = '$_base/downloads';
  static String downloadTrack(String id) => '$_base/downloads/tracks/$id';

  // ── Premium ──────────────────────────────────
  static const String premiumPlans = '$_base/premium/plans';
  static const String premiumSubscribe = '$_base/premium/subscribe';
  static const String premiumRestore = '$_base/premium/restore';

  // ── Notifications ────────────────────────────
  static const String notifications = '$_base/notifications';
  static const String notificationSettings = '$_base/notifications/settings';
  static const String pushToken = '$_base/notifications/push-token';

  // ── Analytics ────────────────────────────────
  static const String analyticsEvent = '$_base/analytics/event';
  static const String analyticsBatch = '$_base/analytics/batch';
  static const String playbackEvent = '$_base/analytics/playback';
}

// ════════════════════════════════════════════════
// Project Lyra — API Constants
// ════════════════════════════════════════════════
//
// Environment-agnostic API configuration.
// Actual URLs come from EnvConfig at runtime.
// ════════════════════════════════════════════════

/// API endpoint paths and header constants.
///
/// Base URLs are injected via [EnvConfig], not hardcoded here.
abstract final class ApiConstants {
  // ── API Versioning ───────────────────────────
  static const String apiVersion = 'v1';
  static const String apiPrefix = '/api/$apiVersion';

  // ── Endpoint Paths ───────────────────────────
  // Auth
  static const String authLogin = '$apiPrefix/auth/login';
  static const String authRegister = '$apiPrefix/auth/register';
  static const String authRefresh = '$apiPrefix/auth/refresh';
  static const String authLogout = '$apiPrefix/auth/logout';
  static const String authGoogle = '$apiPrefix/auth/google';
  static const String authForgotPassword = '$apiPrefix/auth/forgot-password';

  // User
  static const String userProfile = '$apiPrefix/user/profile';
  static const String userPreferences = '$apiPrefix/user/preferences';
  static const String userSubscription = '$apiPrefix/user/subscription';

  // Music
  static const String tracks = '$apiPrefix/tracks';
  static const String albums = '$apiPrefix/albums';
  static const String artists = '$apiPrefix/artists';
  static const String playlists = '$apiPrefix/playlists';
  static const String search = '$apiPrefix/search';
  static const String recommendations = '$apiPrefix/recommendations';
  static const String trending = '$apiPrefix/trending';
  static const String newReleases = '$apiPrefix/new-releases';

  // Podcasts
  static const String podcasts = '$apiPrefix/podcasts';
  static const String podcastEpisodes = '$apiPrefix/podcast-episodes';

  // Audiobooks
  static const String audiobooks = '$apiPrefix/audiobooks';
  static const String audiobookChapters = '$apiPrefix/audiobook-chapters';

  // Streaming
  static const String streamUrl = '$apiPrefix/stream';
  static const String downloadUrl = '$apiPrefix/download';

  // AI Features
  static const String aiSearch = '$apiPrefix/ai/search';
  static const String aiRecommendations = '$apiPrefix/ai/recommendations';
  static const String aiDJ = '$apiPrefix/ai/dj';

  // Analytics
  static const String analyticsEvent = '$apiPrefix/analytics/event';
  static const String analyticsBatch = '$apiPrefix/analytics/batch';

  // ── Headers ──────────────────────────────────
  static const String headerAuth = 'Authorization';
  static const String headerBearer = 'Bearer';
  static const String headerContentType = 'Content-Type';
  static const String headerAccept = 'Accept';
  static const String headerAppVersion = 'X-App-Version';
  static const String headerPlatform = 'X-Platform';
  static const String headerDeviceId = 'X-Device-Id';
  static const String headerRequestId = 'X-Request-Id';
  static const String headerIfNoneMatch = 'If-None-Match';
  static const String headerETag = 'ETag';

  // ── Content Types ────────────────────────────
  static const String contentTypeJson = 'application/json';
  static const String contentTypeMultipart = 'multipart/form-data';
  static const String contentTypeFormData = 'application/x-www-form-urlencoded';
}

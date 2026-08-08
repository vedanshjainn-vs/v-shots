// ════════════════════════════════════════════════
// Project Lyra — Route Names
// ════════════════════════════════════════════════
//
// Named route constants for GoRouter.
// Use names for navigation, paths for deep links.
// ════════════════════════════════════════════════

/// Named route constants.
///
/// GoRouter supports both path-based and name-based navigation.
/// Names are more resilient to path changes.
abstract final class RouteNames {
  static const String splash = 'splash';
  static const String onboarding = 'onboarding';
  static const String login = 'login';
  static const String register = 'register';
  static const String forgotPassword = 'forgot-password';

  static const String home = 'home';
  static const String explore = 'explore';
  static const String library = 'library';
  static const String search = 'search';

  static const String track = 'track';
  static const String album = 'album';
  static const String artist = 'artist';
  static const String playlist = 'playlist';
  static const String podcast = 'podcast';
  static const String audiobook = 'audiobook';
  static const String episode = 'episode';

  static const String player = 'player';
  static const String playerQueue = 'player-queue';
  static const String playerLyrics = 'player-lyrics';

  static const String profile = 'profile';
  static const String settings = 'settings';
  static const String premium = 'premium';
  static const String notifications = 'notifications';
  static const String downloads = 'downloads';
  static const String likedSongs = 'liked-songs';
  static const String recentHistory = 'recent-history';

  static const String aiSearch = 'ai-search';
  static const String aiDJ = 'ai-dj';
  static const String aiRecommendations = 'ai-recommendations';
}

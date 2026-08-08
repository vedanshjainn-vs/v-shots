// ════════════════════════════════════════════════
// Project Lyra — Route Paths
// ════════════════════════════════════════════════
//
// Static path constants for GoRouter.
// Use these everywhere — never hardcode paths.
// ════════════════════════════════════════════════

/// All route paths used in the application.
///
/// Naming convention:
/// - Static paths: `static const String`
/// - Dynamic paths: use `:` prefix for params
/// - Helper methods: for paths with required params
abstract final class RoutePaths {
  // ── Root ─────────────────────────────────────
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';

  // ── Auth ─────────────────────────────────────
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // ── Main Shell (Bottom Nav) ──────────────────
  static const String home = '/home';
  static const String explore = '/explore';
  static const String library = '/library';
  static const String search = '/search';

  // ── Content Detail ───────────────────────────
  static const String track = '/track/:id';
  static const String album = '/album/:id';
  static const String artist = '/artist/:id';
  static const String playlist = '/playlist/:id';
  static const String podcast = '/podcast/:id';
  static const String audiobook = '/audiobook/:id';
  static const String episode = '/episode/:id';

  // ── Player ───────────────────────────────────
  static const String player = '/player';
  static const String playerQueue = '/player/queue';
  static const String playerLyrics = '/player/lyrics';

  // ── Features ─────────────────────────────────
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String premium = '/premium';
  static const String notifications = '/notifications';
  static const String downloads = '/downloads';
  static const String likedSongs = '/liked-songs';
  static const String recentHistory = '/history';
  static const String searchResults = '/search/results';

  // ── AI Features ──────────────────────────────
  static const String aiSearch = '/ai/search';
  static const String aiDJ = '/ai/dj';
  static const String aiRecommendations = '/ai/recommendations';

  // ── Helpers for dynamic paths ────────────────
  static String trackById(String id) => '/track/$id';
  static String albumById(String id) => '/album/$id';
  static String artistById(String id) => '/artist/$id';
  static String playlistById(String id) => '/playlist/$id';
  static String podcastById(String id) => '/podcast/$id';
  static String audiobookById(String id) => '/audiobook/$id';
  static String episodeById(String id) => '/episode/$id';
}

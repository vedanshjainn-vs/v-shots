// ════════════════════════════════════════════════
// Project Lyra — Application Constants
// ════════════════════════════════════════════════
//
// Global app-level constants.
// No secrets here — only public, compile-time values.
// ════════════════════════════════════════════════

/// Application-wide constants.
///
/// For environment-specific values, see [ApiConstants].
/// For storage keys, see [StorageConstants].
/// For asset paths, see [AssetConstants].
abstract final class AppConstants {
  // ── App Identity ─────────────────────────────
  static const String androidPackageName = 'com.vshots.live';
  static const String appName = 'V Shots';
  static const String appVersion = '0.1.0';
  static const String appBuildNumber = '1';

  // ── UI Constants ─────────────────────────────
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double extraLargePadding = 32.0;

  static const double defaultRadius = 16.0;
  static const double smallRadius = 8.0;
  static const double largeRadius = 24.0;
  static const double circularRadius = 999.0;

  static const double bottomNavHeight = 64.0;
  static const double miniPlayerHeight = 64.0;
  static const double appBarHeight = 56.0;
  static const double searchBarHeight = 48.0;

  // ── Music Constants ──────────────────────────
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;
  static const int maxPlaylistTracks = 10_000;
  static const int maxRecentSearches = 10;
  static const int maxRecentlyPlayed = 50;
  static const int crossfadeDurationMs = 3000;
  static const int maxDownloadQuality = 320; // kbps
  static const int defaultBitrate = 128; // kbps

  // ── Animation Durations ──────────────────────
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 250);
  static const Duration shimmerDuration = Duration(milliseconds: 1500);
  static const Duration debounceSearch = Duration(milliseconds: 400);
  static const Duration debounceScroll = Duration(milliseconds: 200);

  // ── Cache Durations ──────────────────────────
  static const Duration shortCache = Duration(minutes: 5);
  static const Duration mediumCache = Duration(hours: 1);
  static const Duration longCache = Duration(days: 1);
  static const Duration persistentCache = Duration(days: 30);

  // ── Timeouts ─────────────────────────────────
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 10);

  // ── Limits ───────────────────────────────────
  static const int maxFileSize = 10 * 1024 * 1024; // 10 MB
  static const int maxImageDimension = 1024;
  static const int minPasswordLength = 8;
  static const int maxNameLength = 50;
  static const int maxBioLength = 300;

  // ── Regex ────────────────────────────────────
  static const String emailPattern =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phonePattern = r'^\+?[1-9]\d{1,14}$';
  static const String urlPattern =
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$';

  // ── Misc ─────────────────────────────────────
  static const String defaultLocale = 'en';
  static const String defaultCountryCode = 'US';
}

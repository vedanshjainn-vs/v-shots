// ════════════════════════════════════════════════
// Project Lyra — Asset Constants
// ════════════════════════════════════════════════
//
// Centralized asset paths.
// Prevents typos and eases refactoring.
// ════════════════════════════════════════════════

/// All static asset paths used in the application.
abstract final class AssetConstants {
  // ── Base Paths ───────────────────────────────
  static const String _images = 'assets/images';
  static const String _animations = 'assets/animations';
  static const String _lottie = 'assets/lottie';

  // ── Images ───────────────────────────────────
  static const String logo = '$_images/logo.png';
  static const String logoLight = '$_images/logo_light.png';
  static const String logoDark = '$_images/logo_dark.png';
  static const String onboarding1 = '$_images/onboarding_1.png';
  static const String onboarding2 = '$_images/onboarding_2.png';
  static const String onboarding3 = '$_images/onboarding_3.png';
  static const String placeholderAlbum = '$_images/placeholder_album.png';
  static const String placeholderArtist = '$_images/placeholder_artist.png';
  static const String placeholderPlaylist = '$_images/placeholder_playlist.png';
  static const String placeholderPodcast = '$_images/placeholder_podcast.png';
  static const String placeholderAudiobook = '$_images/placeholder_audiobook.png';
  static const String placeholderAvatar = '$_images/placeholder_avatar.png';
  static const String emptyLibrary = '$_images/empty_library.png';
  static const String emptySearch = '$_images/empty_search.png';
  static const String noConnection = '$_images/no_connection.png';
  static const String premiumStar = '$_images/premium_star.png';

  // ── Lottie Animations ────────────────────────
  static const String loadingPulse = '$_lottie/loading_pulse.json';
  static const String loadingBars = '$_lottie/loading_bars.json';
  static const String emptyState = '$_lottie/empty_state.json';
  static const String errorState = '$_lottie/error_state.json';
  static const String successCheck = '$_lottie/success_check.json';
  static const String musicPlaying = '$_lottie/music_playing.json';
  static const String downloadComplete = '$_lottie/download_complete.json';
  static const String confetti = '$_lottie/confetti.json';

  // ── Animations ───────────────────────────────
  static const String splashReveal = '$_animations/splash_reveal.json';
  static const String likeAnimation = '$_animations/like_animation.json';
}

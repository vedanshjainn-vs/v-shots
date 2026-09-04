// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Placement Cadence
//
// In-feed ad spacing constants (kept here for the placement screens and
// tests). All availability/config decisions live in AdPolicy / MaxConfig /
// VShotsMax — this file has NO credentials and NO SDK logic.
// ═════════════════════════════════════════════════════════════════════════

class AdConfig {
  AdConfig._();

  /// Search: insert one clearly-labeled MREC after this many organic results.
  static const int searchAdEvery = 5;

  /// Discover (For You): insert one clearly-separated MREC page after this
  /// many organic videos. The ad remains a swipable in-feed page with a
  /// Continue control and never touches the player.
  static const int discoveryAdEvery = 3;

  /// Playlist pages: one ad card after this many tracks (max 1/page).
  static const int playlistAdAfter = 7;
}

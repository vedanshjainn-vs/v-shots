// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Placement Cadence
//
// In-feed ad spacing constants (kept here for the placement screens and
// tests). All availability/config decisions live in AdPolicy / MaxConfig /
// VShotsMax — this file has NO credentials and NO SDK logic.
//
// (Pre-MAX-migration this file held Google AdMob unit IDs; those are
// obsolete — AdMob demand now flows through AppLovin MAX mediation and is
// configured in the MAX dashboard, not on the client.)
// ═════════════════════════════════════════════════════════════════════════

class AdConfig {
  AdConfig._();

  /// Search: insert one clearly-labeled native ad after this many organic
  /// results.
  static const int searchAdEvery = 8;

  /// Discover (For You): insert one clearly-separated ad page after this
  /// many organic videos. Tuned for premium feel — user enjoys a meaningful
  /// listening session before an ad appears (2026-09-03: 6, up from 4).
  /// The ad remains a swipable in-feed page with a Continue control and
  /// never touches the player.
  static const int discoveryAdEvery = 6;

  /// Playlist pages: one native card after this many tracks (max 1/page).
  static const int playlistAdAfter = 10;
}

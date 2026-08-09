// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: Feed intents (Phase 7, Part Q)
// ════════════════════════════════════════════════
//
// Each intent uses different ranking logic per Part Q's explicit
// instruction ("Each should use different ranking logic") —
// implemented as different CANDIDATE SOURCE FILTERS/WEIGHT PROFILES
// over the same underlying pipeline (candidate generation -> scoring
// -> diversity), rather than N entirely separate pipelines, per this
// task's own "ONE reusable animation/pipeline system" philosophy
// applied here too — one engine, parameterized per intent.
// ════════════════════════════════════════════════

enum FeedIntent {
  /// General personalized feed — the default "For You" (Discover tab).
  forYou,

  /// Explicitly artist-affinity-driven — "Because You Listened To
  /// {artist}".
  becauseYouListenedTo,

  /// Content-similarity-driven from a specific seed track — "More
  /// Like This".
  moreLikeThis,

  /// Home's personalized row — reuses the same taste profile as
  /// [forYou] but returns a smaller, single-query-style batch (Home
  /// shows a static row, not an infinite feed).
  madeForYou,

  /// Trending content re-ranked by the user's own taste where
  /// possible — "Trending For You" (trending pool, personalized order).
  trendingForYou,

  /// Recently-played-driven — surfaces tracks similar to what's
  /// currently in heavy rotation, not brand new discovery.
  continueListening,

  /// High-novelty, low-affinity-weighted — the Discover tab's
  /// exploration surface (Part W).
  discoverSomethingNew,

  /// Artist-similarity-driven, similar to [becauseYouListenedTo] but
  /// framed around exploring an artist's neighborhood rather than a
  /// specific completed listen.
  similarArtists,
}

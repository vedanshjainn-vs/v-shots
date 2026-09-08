// ═════════════════════════════════════════════════════════════════════════
// V Shots — Recommendation Engine: Feed Intents (V2 Engine)
// ═════════════════════════════════════════════════════════════════════════

enum FeedIntent {
  /// General personalized feed — Discover tab default.
  forYou,

  /// Explicitly artist-affinity-driven — "Because You Listened To {artist}".
  becauseYouListenedTo,

  /// Content-similarity-driven from a specific seed track — "More Like This".
  moreLikeThis,

  /// Home's personalized row — highest relevance scored tracks.
  madeForYou,

  /// Immediate current intent — recent listens, searches, unfinished, replayed tracks.
  quickPicks,

  /// Trending content re-ranked by the user's own taste where possible.
  trendingForYou,

  /// Recently-played-driven — surfaces tracks from current rotation.
  continueListening,

  /// High-novelty, low-affinity-weighted exploration surface.
  discoverSomethingNew,

  /// Artist-similarity-driven neighborhood exploration.
  similarArtists,
}

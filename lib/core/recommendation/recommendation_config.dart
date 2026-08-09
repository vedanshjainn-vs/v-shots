// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: configurable weights (Phase 7, Part K)
// ════════════════════════════════════════════════
//
// Per the task's explicit instruction ("Weights should be
// configurable... Do NOT hardcode everything inside UI... Create
// RecommendationConfig so weights can be adjusted later"), every
// number the scoring/diversity/exploration logic uses lives here, not
// scattered as magic numbers inside `RecommendationScorer`/
// `DiversityFilter`/the UI.
// ════════════════════════════════════════════════

class RecommendationConfig {
  const RecommendationConfig({
    this.weightUserAffinity = 1.0,
    this.weightArtistAffinity = 1.0,
    this.weightRecency = 0.6,
    this.weightSimilarity = 0.8,
    this.weightCompletionProbability = 0.7,
    this.weightPopularity = 0.3,
    this.weightContextMatch = 0.4,
    this.weightNovelty = 0.5,
    this.weightSkipPenalty = 1.2,
    this.weightRepetitionPenalty = 0.9,
    this.explorationRate = 0.15,
    this.maxConsecutiveSameArtist = 2,
    this.skipPenaltyHalfLifeHours = 48,
    this.affinityHalfLifeHours = 72,
  });

  // ── Scoring weights (Part K) ────────────────────────────────────
  final double weightUserAffinity;
  final double weightArtistAffinity;
  final double weightRecency;
  final double weightSimilarity;
  final double weightCompletionProbability;
  final double weightPopularity;
  final double weightContextMatch;
  final double weightNovelty;
  final double weightSkipPenalty;
  final double weightRepetitionPenalty;

  // ── Exploration (Part O) ────────────────────────────────────────
  /// Fraction of a feed batch that should be genuine exploration
  /// (novel artists/genres outside the user's established taste)
  /// rather than pure personalization. 0.15 = 15% exploration, 85%
  /// personalized — within the task's suggested 10-20% range.
  final double explorationRate;

  // ── Diversity (Part N) ──────────────────────────────────────────
  /// Maximum consecutive tracks from the same artist allowed in a
  /// ranked feed before diversity re-ordering kicks in.
  final int maxConsecutiveSameArtist;

  // ── Decay half-lives (Part I: "do not permanently punish an artist
  // based on one skip") ───────────────────────────────────────────
  /// A skip's negative weight decays with this half-life — a skip from
  /// an hour ago matters far more than one from a week ago, so a
  /// single bad skip does not permanently exclude an artist.
  final double skipPenaltyHalfLifeHours;

  /// Positive affinity (plays/likes/completions) decays with this
  /// half-life — matches ForYouFeedService v2's existing 72-hour
  /// recency half-life (kept consistent, not reinvented).
  final double affinityHalfLifeHours;

  static const defaultConfig = RecommendationConfig();
}

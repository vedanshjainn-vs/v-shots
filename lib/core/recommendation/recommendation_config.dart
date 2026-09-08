// ═════════════════════════════════════════════════════════════════════════
// V Shots — Recommendation Engine: Configurable Weights (V2 Engine)
// ═════════════════════════════════════════════════════════════════════════

class RecommendationConfig {
  const RecommendationConfig({
    this.weightUserAffinity = 1.0,
    this.weightArtistAffinity = 1.0,
    this.weightSearchAffinity = 1.2,
    this.weightGenreAffinity = 0.8,
    this.weightLanguageAffinity = 0.8,
    this.weightMoodAffinity = 0.5,
    this.weightRecency = 0.6,
    this.weightSimilarity = 0.8,
    this.weightCompletionProbability = 0.7,
    this.weightReplaySignal = 1.0,
    this.weightPopularity = 0.3,
    this.weightContextMatch = 0.4,
    this.weightNovelty = 0.5,
    this.weightOfficialBoost = 0.35,
    this.weightFreshness = 0.5,
    this.weightSkipPenalty = 1.2,
    this.weightRepetitionPenalty = 0.9,
    this.weightSeenPenalty = 0.7,
    this.weightArtistFatigue = 0.8,
    this.explorationRate = 0.15,
    this.maxConsecutiveSameArtist = 2,
    this.skipPenaltyHalfLifeHours = 48,
    this.affinityHalfLifeHours = 72,
    this.shortTermHalfLifeHours = 24,
  });

  // ── Scoring weights ─────────────────────────────────────────────
  final double weightUserAffinity;
  final double weightArtistAffinity;
  final double weightSearchAffinity;
  final double weightGenreAffinity;
  final double weightLanguageAffinity;
  final double weightMoodAffinity;
  final double weightRecency;
  final double weightSimilarity;
  final double weightCompletionProbability;
  final double weightReplaySignal;
  final double weightPopularity;
  final double weightContextMatch;
  final double weightNovelty;
  final double weightOfficialBoost;
  final double weightFreshness;
  final double weightSkipPenalty;
  final double weightRepetitionPenalty;
  final double weightSeenPenalty;
  final double weightArtistFatigue;

  // ── Exploration & Diversity ─────────────────────────────────────
  final double explorationRate;
  final int maxConsecutiveSameArtist;

  // ── Decay half-lives ────────────────────────────────────────────
  final double skipPenaltyHalfLifeHours;
  final double affinityHalfLifeHours;
  final double shortTermHalfLifeHours;

  static const defaultConfig = RecommendationConfig();
}

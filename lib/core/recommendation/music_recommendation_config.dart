// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music recommendation configuration (weights, half-lives, quotas)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:math';

/// Signal → affinity weights (same scale as the existing taste engine).
class MusicSignalWeights {
  static const double play = 1.0;
  static const double longListen = 2.0;
  static const double completed = 3.0;
  static const double replay = 4.0;
  static const double like = 5.0;
  static const double playlistAdd = 3.5;
  static const double immediateSkip = -2.5;
  static const double shortSkip = -1.5;
  static const double lateSkip = -0.5;
}

/// Recency decay (half-life in hours). Pure + deterministic.
double musicDecay({
  required DateTime timestamp,
  required double halfLifeHours,
}) {
  final hours = DateTime.now().difference(timestamp).inMinutes / 60.0;
  return pow(0.5, hours / halfLifeHours).toDouble();
}

class MusicRecommendationConfig {
  const MusicRecommendationConfig({
    this.artistAffinityHalfLifeHours = 336,
    this.genreAffinityHalfLifeHours = 504,
    this.skipPenaltyHalfLifeHours = 168,
    this.sessionHalfLifeHours = 24,
    this.explorationRatio = 0.25,
    this.minHorizontalShelf = 5,
    // For You scoring weights (all features normalized to 0..1 first).
    this.wArtist = 0.22,
    this.wSong = 0.12,
    this.wGenre = 0.10,
    this.wLanguage = 0.08,
    this.wMood = 0.05,
    this.wAlbum = 0.05,
    this.wRecency = 0.08,
    this.wQuality = 0.10,
    this.wOfficiality = 0.07,
    this.wFreshness = 0.05,
    this.wNovelty = 0.08,
    this.wPopularity = 0.05,
    this.wSeenPenalty = 0.10,
    this.wSkipPenalty = 0.15,
    this.wRepetitionPenalty = 0.15,
    // Candidate pool quotas (fractions of the final count).
    this.favoriteArtistQuota = 0.25,
    this.genreLanguageQuota = 0.20,
    this.recentQuota = 0.15,
    this.newMusicQuota = 0.15,
    this.trendingQuota = 0.10,
    this.explorationQuota = 0.15,
  });

  final double artistAffinityHalfLifeHours;
  final double genreAffinityHalfLifeHours;
  final double skipPenaltyHalfLifeHours;
  final double sessionHalfLifeHours;
  final double explorationRatio;
  final int minHorizontalShelf;

  final double wArtist;
  final double wSong;
  final double wGenre;
  final double wLanguage;
  final double wMood;
  final double wAlbum;
  final double wRecency;
  final double wQuality;
  final double wOfficiality;
  final double wFreshness;
  final double wNovelty;
  final double wPopularity;
  final double wSeenPenalty;
  final double wSkipPenalty;
  final double wRepetitionPenalty;

  final double favoriteArtistQuota;
  final double genreLanguageQuota;
  final double recentQuota;
  final double newMusicQuota;
  final double trendingQuota;
  final double explorationQuota;

  static const defaultConfig = MusicRecommendationConfig();
}

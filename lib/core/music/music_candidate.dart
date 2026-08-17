// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music candidate model
// ═════════════════════════════════════════════════════════════════════════════

import '../providers/provider_models.dart';

/// One recommendation candidate: a resolved track + WHERE it came from.
class MusicCandidate {
  const MusicCandidate({
    required this.track,
    required this.songId,
    required this.source,
    this.seedArtist,
    this.seedGenre,
    this.seedSong,
    this.artist = '',
    this.genre = '',
    this.language = '',
    this.album = '',
  });

  final ProviderTrack track;

  /// Canonical song identity (never the YouTube videoId).
  final String songId;

  /// Pool source: favorite_artist / similar_artist / favorite_genre /
  /// favorite_language / recent_artist / trending / new_release / regional /
  /// mood / exploration / cold_start.
  final String source;

  final String? seedArtist;
  final String? seedGenre;
  final String? seedSong;

  // Resolved dimensions used by diversity/scoring.
  final String artist;
  final String genre;
  final String language;
  final String album;
}

/// A candidate with its computed score.
class ScoredMusicCandidate {
  const ScoredMusicCandidate({required this.candidate, required this.score});

  final MusicCandidate candidate;
  final double score;
}

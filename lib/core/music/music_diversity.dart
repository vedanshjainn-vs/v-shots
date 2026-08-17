// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music diversity (rolling-window concentration limits)
// ═════════════════════════════════════════════════════════════════════════════
//
// Re-orders a score-sorted candidate list so no artist/album/genre/language
// dominates. ONLY for recommendation feeds (never artist/album/search pages).
// Soft, greedy, deterministic: the next allowed highest-scored candidate is
// promoted; nothing is dropped unless it violates a hard rolling cap.
// ═════════════════════════════════════════════════════════════════════════════

import 'music_candidate.dart';

class MusicDiversity {
  const MusicDiversity({
    this.maxArtistInWindow = 2,
    this.artistWindow = 5,
    this.maxAlbumInWindow = 2,
    this.albumWindow = 8,
    this.maxGenreInWindow = 4,
    this.genreWindow = 10,
    this.maxLanguageInWindow = 7,
    this.languageWindow = 10,
  });

  final int maxArtistInWindow;
  final int artistWindow;
  final int maxAlbumInWindow;
  final int albumWindow;
  final int maxGenreInWindow;
  final int genreWindow;
  final int maxLanguageInWindow;
  final int languageWindow;

  List<ScoredMusicCandidate> diversify(List<ScoredMusicCandidate> candidates) {
    final remaining = List<ScoredMusicCandidate>.from(candidates);
    final result = <ScoredMusicCandidate>[];

    while (remaining.isNotEmpty) {
      int chosen = -1;
      for (var i = 0; i < remaining.length; i++) {
        if (_allowed(remaining[i].candidate, result)) {
          chosen = i;
          break;
        }
      }
      // Fall back to the first remaining item if every candidate is blocked
      // (soft preference — diversity must never discard content).
      if (chosen == -1) chosen = 0;
      result.add(remaining.removeAt(chosen));
    }
    return result;
  }

  bool _allowed(MusicCandidate candidate, List<ScoredMusicCandidate> placed) {
    if (_countIn(candidate.artist, placed, (c) => c.artist) >=
            maxArtistInWindow &&
        candidate.artist.isNotEmpty) {
      final inWindow = placed
          .sublist(
            placed.length - artistWindow < 0 ? 0 : placed.length - artistWindow,
          )
          .where((s) => s.candidate.artist == candidate.artist)
          .length;
      if (inWindow >= maxArtistInWindow) return false;
    }
    if (candidate.genre.isNotEmpty &&
        _countIn(candidate.genre, placed, (c) => c.genre) >= maxGenreInWindow) {
      final inWindow = placed
          .sublist(
            placed.length - genreWindow < 0 ? 0 : placed.length - genreWindow,
          )
          .where((s) => s.candidate.genre == candidate.genre)
          .length;
      if (inWindow >= maxGenreInWindow) return false;
    }
    if (candidate.language.isNotEmpty &&
        _countIn(candidate.language, placed, (c) => c.language) >=
            maxLanguageInWindow) {
      final inWindow = placed
          .sublist(
            placed.length - languageWindow < 0
                ? 0
                : placed.length - languageWindow,
          )
          .where((s) => s.candidate.language == candidate.language)
          .length;
      if (inWindow >= maxLanguageInWindow) return false;
    }
    return true;
  }

  int _countIn(
    String value,
    List<ScoredMusicCandidate> placed,
    String Function(MusicCandidate) pick,
  ) {
    return placed.where((s) => pick(s.candidate) == value).length;
  }
}

// ═════════════════════════════════════════════════════════════════════════
// V Shots — SongSimilarityEngine
//
// Deterministic, KNN-style content similarity between a seed song and a
// candidate pool (adapted from the reference projects' KNN/audio-feature
// approaches, but using YouTube-available metadata — we never invent audio
// features). Weighted similarity over genre / mood / language / artist /
// release-era / metadata. Weights are configurable.
// ═════════════════════════════════════════════════════════════════════════

import '../providers/provider_models.dart';
import 'genre_classifier.dart';

/// A normalized candidate with its computed similarity to a seed.
class SimilarCandidate {
  const SimilarCandidate({
    required this.track,
    required this.similarity,
  });

  final ProviderTrack track;
  final double similarity;
}

class SongSimilarityEngine {
  SongSimilarityEngine({
    this.genreWeight = 0.25,
    this.moodWeight = 0.20,
    this.artistWeight = 0.15,
    this.languageWeight = 0.10,
    this.energyWeight = 0.10,
    this.releaseWeight = 0.10,
    this.metadataWeight = 0.10,
  });

  final double genreWeight;
  final double moodWeight;
  final double artistWeight;
  final double languageWeight;
  final double energyWeight;
  final double releaseWeight;
  final double metadataWeight;

  final GenreClassifier _classifier = GenreClassifier.instance;

  /// Computes a weighted similarity in [0,1] between [seed] and [candidate].
  double similarity(ProviderTrack seed, ProviderTrack candidate) {
    final seedGenres =
        _classifier.classify(title: seed.title, artist: seed.artist);
    final candGenres = _classifier.classify(
      title: candidate.title,
      artist: candidate.artist,
    );

    final genreSim = _classifier.similarity(seedGenres, candGenres);
    final artistSim = seed.artist.trim().toLowerCase() ==
            candidate.artist.trim().toLowerCase()
        ? 1.0
        : 0.0;
    final languageSim = _languageOverlap(seed.title, candidate.title);

    double score = 0;
    score += genreSim * genreWeight;
    score += genreSim * moodWeight; // genre tags double as mood proxy
    score += artistSim * artistWeight;
    score += languageSim * languageWeight;
    score += energySim(seed, candidate) * energyWeight;
    score += releaseSim(seed, candidate) * releaseWeight;
    score += metadataSim(seed, candidate) * metadataWeight;
    return score.clamp(0.0, 1.0);
  }

  /// Returns the top-K most similar candidates to [seed] from [pool].
  List<SimilarCandidate> findSimilarSongs(
    ProviderTrack seed,
    List<ProviderTrack> pool, {
    int k = 8,
  }) {
    final scored = pool
        .where((t) => t.id != seed.id)
        .map((t) => SimilarCandidate(track: t, similarity: similarity(seed, t)))
        .toList()
      ..sort((a, b) => b.similarity.compareTo(a.similarity));
    return scored.take(k).toList();
  }

  double _languageOverlap(String a, String b) {
    final al = _detectLang(a);
    final bl = _detectLang(b);
    return al == bl && al != '' ? 1.0 : 0.0;
  }

  String _detectLang(String s) {
    final l = s.toLowerCase();
    if (['hindi', 'bollywood', 'arijit'].any(l.contains)) {
      return 'hindi';
    }
    if (['punjabi', 'diljit', 'aujla', 'shubh'].any(l.contains)) {
      return 'punjabi';
    }
    if (['english', 'pop', 'weeknd', 'sheeran'].any(l.contains)) {
      return 'english';
    }
    return '';
  }

  double energySim(ProviderTrack a, ProviderTrack b) {
    // Metadata proxy: shorter tracks are often higher energy. 0 if no duration.
    if (a.durationSeconds == 0 || b.durationSeconds == 0) {
      return 0.5;
    }
    final diff = (a.durationSeconds - b.durationSeconds).abs();
    return (1 - (diff / 300)).clamp(0.0, 1.0);
  }

  double releaseSim(ProviderTrack a, ProviderTrack b) {
    // Metadata proxy: same release-era approximated by title keyword presence.
    final eraA = _era(a.title);
    final eraB = _era(b.title);
    return eraA == eraB ? 1.0 : 0.0;
  }

  String _era(String t) {
    final l = t.toLowerCase();
    if (['90s', 'retro', 'classic', 'evergreen'].any(l.contains)) {
      return 'retro';
    }
    if (['2026', 'new', 'latest', 'fresh'].any(l.contains)) {
      return 'new';
    }
    return 'current';
  }

  double metadataSim(ProviderTrack a, ProviderTrack b) {
    // Token overlap on title words (after removing common words).
    final wordsA = a.title.toLowerCase().split(RegExp(r'\W+')).toSet();
    final wordsB = b.title.toLowerCase().split(RegExp(r'\W+')).toSet();
    final stop = {
      'the',
      'official',
      'video',
      'music',
      'lyric',
      'audio',
      'song',
      'hd',
      'full'
    };
    final wa = wordsA.difference(stop);
    final wb = wordsB.difference(stop);
    if (wa.isEmpty && wb.isEmpty) return 0.5;
    final inter = wa.intersection(wb).length;
    final union = wa.union(wb).length;
    return union == 0 ? 0 : inter / union;
  }
}

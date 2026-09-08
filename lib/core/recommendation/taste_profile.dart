// ═════════════════════════════════════════════════════════════════════════
// V Shots — Recommendation Engine: User Taste Profile (V2 Engine)
// ═════════════════════════════════════════════════════════════════════════
//
// Multi-dimensional behavioral taste model:
//   - ARTIST, GENRE, LANGUAGE, MOOD, SEARCH, PLAYLIST, SONG affinities
//   - Per-artist historical completion rates and repeat/replay rates
//   - Decayed skip penalties and negative taste clusters
//   - Time-decay: short-term session intent vs long-term taste memory
//   - Explicit 5-tier maturity progression (COLD -> EARLY -> EMERGING -> CONFIDENT -> MATURE)
// ═════════════════════════════════════════════════════════════════════════

import 'dart:math';

import 'genre_classifier.dart';
import 'recommendation_config.dart';
import 'signal_event.dart';
import 'signal_store.dart';

/// Explicit maturity stages for progressive personalization.
enum TasteMaturity {
  /// < 3 signals: No user history. Safe broad discovery, no fake personalization.
  cold,

  /// 3-9 signals: Earliest explicit intent (searches / first plays). Low confidence.
  earlySignal,

  /// 10-29 signals: Clear emerging preferences. Personalized Home begins dominating.
  emerging,

  /// 30-99 signals: Strong multi-dimensional preferences and high confidence.
  confident,

  /// 100+ signals: Deep long-term profile + dynamic short-term session blending.
  mature,
}

class TasteProfile {
  const TasteProfile({
    required this.artistAffinity,
    required this.genreAffinity,
    required this.artistSkipPenalty,
    required this.totalSignalCount,
    this.languageAffinity = const {},
    this.moodAffinity = const {},
    this.searchAffinity = const {},
    this.playlistAffinity = const {},
    this.songAffinity = const {},
    this.artistCompletionRate = const {},
    this.artistRepeatRate = const {},
    this.negativeTaste = const {},
    this.confidenceScores = const {},
    this.maturity = TasteMaturity.cold,
    this.shortTermArtists = const {},
    this.shortTermGenres = const {},
    this.longTermArtists = const {},
    this.longTermGenres = const {},
  });

  final Map<String, double> artistAffinity;
  final Map<String, double> genreAffinity;
  final Map<String, double> languageAffinity;
  final Map<String, double> moodAffinity;
  final Map<String, double> searchAffinity;
  final Map<String, double> playlistAffinity;
  final Map<String, double> songAffinity;
  final Map<String, double> artistSkipPenalty;
  final Map<String, double> artistCompletionRate;
  final Map<String, double> artistRepeatRate;
  final Map<String, double> negativeTaste;
  final Map<String, double> confidenceScores;
  final TasteMaturity maturity;
  final Set<String> shortTermArtists;
  final Set<String> shortTermGenres;
  final Set<String> longTermArtists;
  final Set<String> longTermGenres;
  final int totalSignalCount;

  bool get hasEnoughHistoryForPersonalization =>
      totalSignalCount >= 3 || maturity != TasteMaturity.cold;

  static const empty = TasteProfile(
    artistAffinity: {},
    genreAffinity: {},
    languageAffinity: {},
    moodAffinity: {},
    searchAffinity: {},
    playlistAffinity: {},
    songAffinity: {},
    artistSkipPenalty: {},
    artistCompletionRate: {},
    artistRepeatRate: {},
    negativeTaste: {},
    confidenceScores: {},
    maturity: TasteMaturity.cold,
    shortTermArtists: {},
    shortTermGenres: {},
    longTermArtists: {},
    longTermGenres: {},
    totalSignalCount: 0,
  );

  List<String> get topArtists {
    final sorted = artistAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  List<String> get topGenres {
    final sorted = genreAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  List<String> get topLanguages {
    final sorted = languageAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  List<String> get topMoods {
    final sorted = moodAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  List<String> get topSearches {
    final sorted = searchAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }
}

class TasteProfileBuilder {
  TasteProfileBuilder({
    this.config = RecommendationConfig.defaultConfig,
    GenreClassifier? genreClassifier,
  }) : _genres = genreClassifier ?? GenreClassifier.instance;

  final RecommendationConfig config;
  final GenreClassifier _genres;

  /// Builds a [TasteProfile] from [events] (defaults to
  /// `SignalStore.instance.events` for production, accepts explicit events for testing).
  TasteProfile build({List<SignalEvent>? events}) {
    final signals = events ?? SignalStore.instance.events;
    if (signals.isEmpty) return TasteProfile.empty;

    final now = DateTime.now();
    final artistAffinity = <String, double>{};
    final genreAffinity = <String, double>{};
    final languageAffinity = <String, double>{};
    final moodAffinity = <String, double>{};
    final searchAffinity = <String, double>{};
    final playlistAffinity = <String, double>{};
    final songAffinity = <String, double>{};
    final artistSkipPenalty = <String, double>{};
    final negativeTaste = <String, double>{};

    final artistPlays = <String, int>{};
    final artistCompletions = <String, int>{};
    final artistSkips = <String, int>{};
    final artistReplays = <String, int>{};

    final shortTermArtists = <String>{};
    final shortTermGenres = <String>{};
    final longTermArtists = <String>{};
    final longTermGenres = <String>{};

    for (final event in signals) {
      final hoursAgo = now.difference(event.timestamp).inMinutes / 60.0;
      final longTermDecay = pow(
        0.5,
        hoursAgo / config.affinityHalfLifeHours,
      ).toDouble();
      final skipDecay = pow(
        0.5,
        hoursAgo / config.skipPenaltyHalfLifeHours,
      ).toDouble();
      final isShortTerm = hoursAgo <= config.shortTermHalfLifeHours;

      final artist = event.artist?.trim();
      final title = event.title?.trim();
      final query = event.query?.trim();
      final playlist = event.playlistTheme?.trim();
      final weight = _weightFor(event);

      // ── 1. Explicit Search Intent (Top Positive Weight) ─────────────────
      if (event.type == SignalType.search && query != null && query.isNotEmpty) {
        final searchWeight = weight * longTermDecay;
        searchAffinity[query] = (searchAffinity[query] ?? 0) + searchWeight;

        // Search text entity analysis: detect genres, languages, and moods
        final detectedGenres = _genres.classify(title: query, artist: '');
        for (final g in detectedGenres) {
          genreAffinity[g] = (genreAffinity[g] ?? 0) + searchWeight * 0.8;
          if (isShortTerm) shortTermGenres.add(g);
          longTermGenres.add(g);
        }
        final detectedLangs = _genres.detectLanguages(query);
        for (final l in detectedLangs) {
          languageAffinity[l] = (languageAffinity[l] ?? 0) + searchWeight * 0.8;
        }
        final detectedMoods = _genres.detectMoods(query);
        for (final m in detectedMoods) {
          moodAffinity[m] = (moodAffinity[m] ?? 0) + searchWeight * 0.7;
        }

        // If query looks like an artist name or has significant searches
        artistAffinity[query] = (artistAffinity[query] ?? 0) + searchWeight * 0.9;
        if (isShortTerm) shortTermArtists.add(query);
        longTermArtists.add(query);
      }

      // ── 2. Playlist Engagement ──────────────────────────────────────────
      if ((event.type == SignalType.playlistOpen ||
              event.type == SignalType.playlistInteraction) &&
          playlist != null &&
          playlist.isNotEmpty) {
        final plWeight = weight * longTermDecay;
        playlistAffinity[playlist] = (playlistAffinity[playlist] ?? 0) + plWeight;
        final pGenres = _genres.classify(title: playlist, artist: '');
        for (final g in pGenres) {
          genreAffinity[g] = (genreAffinity[g] ?? 0) + plWeight * 0.6;
        }
        final pLangs = _genres.detectLanguages(playlist);
        for (final l in pLangs) {
          languageAffinity[l] = (languageAffinity[l] ?? 0) + plWeight * 0.6;
        }
        final pMoods = _genres.detectMoods(playlist);
        for (final m in pMoods) {
          moodAffinity[m] = (moodAffinity[m] ?? 0) + plWeight * 0.6;
        }
      }

      // ── 3. Track-Level Signals (Plays, Completions, Skips, Likes, Replays)
      if (artist != null && artist.isNotEmpty) {
        if (event.type == SignalType.skip) {
          artistSkips[artist] = (artistSkips[artist] ?? 0) + 1;
          artistPlays[artist] = (artistPlays[artist] ?? 0) + 1;

          // Track skip penalty separately with decay
          artistSkipPenalty[artist] =
              (artistSkipPenalty[artist] ?? 0) + weight.abs() * skipDecay;

          // Repeated skip intelligence: negative taste accumulates with consecutive skips
          if ((artistSkips[artist] ?? 0) >= 3) {
            negativeTaste[artist] =
                (negativeTaste[artist] ?? 0) + weight.abs() * skipDecay;
          }

          if (title != null && title.isNotEmpty) {
            final tags = _genres.classify(title: title, artist: artist);
            for (final tag in tags) {
              final genreWeight = -weight.abs() * skipDecay * 0.4;
              genreAffinity[tag] = (genreAffinity[tag] ?? 0) + genreWeight;
            }
          }
        } else {
          // Positive actions
          if (event.type == SignalType.play ||
              event.type == SignalType.completed ||
              event.type == SignalType.replay ||
              event.type == SignalType.playDuration) {
            artistPlays[artist] = (artistPlays[artist] ?? 0) + 1;
            if (event.type == SignalType.completed) {
              artistCompletions[artist] = (artistCompletions[artist] ?? 0) + 1;
            }
            if (event.type == SignalType.replay) {
              artistReplays[artist] = (artistReplays[artist] ?? 0) + 1;
            }
          }

          artistAffinity[artist] =
              (artistAffinity[artist] ?? 0) + weight * longTermDecay;

          if (isShortTerm) {
            shortTermArtists.add(artist);
          }
          longTermArtists.add(artist);

          if (event.trackId != null && weight > 0) {
            songAffinity[event.trackId!] =
                (songAffinity[event.trackId!] ?? 0) + weight * longTermDecay;
          }

          if (title != null && title.isNotEmpty) {
            final tags = _genres.classify(title: title, artist: artist);
            for (final tag in tags) {
              genreAffinity[tag] =
                  (genreAffinity[tag] ?? 0) + weight * longTermDecay;
              if (isShortTerm) shortTermGenres.add(tag);
              longTermGenres.add(tag);
            }
            final text = '$title $artist';
            final langs = _genres.detectLanguages(text);
            for (final l in langs) {
              languageAffinity[l] =
                  (languageAffinity[l] ?? 0) + weight * longTermDecay;
            }
            final moods = _genres.detectMoods(text);
            for (final m in moods) {
              moodAffinity[m] =
                  (moodAffinity[m] ?? 0) + weight * longTermDecay;
            }
          }
        }
      }
    }

    // Clamp non-negative affinities
    genreAffinity.updateAll((key, value) => max(0, value));
    languageAffinity.updateAll((key, value) => max(0, value));
    moodAffinity.updateAll((key, value) => max(0, value));

    // ── 4. Historical Completion & Replay Rates ─────────────────────────
    final artistCompletionRate = <String, double>{};
    final artistRepeatRate = <String, double>{};

    for (final entry in artistPlays.entries) {
      final a = entry.key;
      final total = entry.value;
      if (total > 0) {
        final comps = artistCompletions[a] ?? 0;
        artistCompletionRate[a] = (comps / total).clamp(0.0, 1.0);
        final reps = artistReplays[a] ?? 0;
        artistRepeatRate[a] = (reps / total).clamp(0.0, 1.0);
      }
    }

    // ── 5. Explicit Maturity Level ───────────────────────────────────────
    final totalCount = signals.length;
    final maturity = _calculateMaturity(totalCount);

    // ── 6. Per-Dimension Confidence Scores (0.0 .. 1.0) ──────────────────
    final confidenceScores = <String, double>{
      'artist': (1.0 - pow(0.5, artistAffinity.length / 4.0)).toDouble().clamp(0.0, 1.0),
      'genre': (1.0 - pow(0.5, genreAffinity.length / 3.0)).toDouble().clamp(0.0, 1.0),
      'language': (1.0 - pow(0.5, languageAffinity.length / 2.0)).toDouble().clamp(0.0, 1.0),
      'search': (1.0 - pow(0.5, searchAffinity.length / 3.0)).toDouble().clamp(0.0, 1.0),
      'overall': (totalCount / 50.0).clamp(0.0, 1.0),
    };

    return TasteProfile(
      artistAffinity: artistAffinity,
      genreAffinity: genreAffinity,
      languageAffinity: languageAffinity,
      moodAffinity: moodAffinity,
      searchAffinity: searchAffinity,
      playlistAffinity: playlistAffinity,
      songAffinity: songAffinity,
      artistSkipPenalty: artistSkipPenalty,
      artistCompletionRate: artistCompletionRate,
      artistRepeatRate: artistRepeatRate,
      negativeTaste: negativeTaste,
      confidenceScores: confidenceScores,
      maturity: maturity,
      shortTermArtists: shortTermArtists,
      shortTermGenres: shortTermGenres,
      longTermArtists: longTermArtists,
      longTermGenres: longTermGenres,
      totalSignalCount: totalCount,
    );
  }

  TasteMaturity _calculateMaturity(int count) {
    if (count < 3) return TasteMaturity.cold;
    if (count < 10) return TasteMaturity.earlySignal;
    if (count < 30) return TasteMaturity.emerging;
    if (count < 100) return TasteMaturity.confident;
    return TasteMaturity.mature;
  }

  /// Exact signal weight hierarchy.
  double _weightFor(SignalEvent event) {
    switch (event.type) {
      case SignalType.search:
        return 6.0; // Explicit user search = highest positive intent
      case SignalType.like:
        return 5.0; // Explicit like/save
      case SignalType.replay:
        return 4.5; // Very strong repeat listen
      case SignalType.completed:
        return 3.5; // High completion (finished)
      case SignalType.addToPlaylist:
        return 3.5; // Deliberate playlist curation
      case SignalType.playlistOpen:
      case SignalType.playlistInteraction:
        return 3.0; // Playlist theme engagement
      case SignalType.discoveryListen:
        return 2.5; // Discovery long listen
      case SignalType.playDuration:
        final seconds = event.value ?? 0;
        if (seconds < 10) return -2.5; // early exit (<10s)
        if (seconds < 30) return -1.0;
        if (seconds < 60) return 0.5;
        if (seconds < 120) return 1.5;
        return min(3.0, seconds / 60.0);
      case SignalType.play:
        return 1.0; // baseline play start
      case SignalType.unlike:
        return -1.5; // mild negative
      case SignalType.removeFromPlaylist:
        return -1.0; // mild negative
      case SignalType.discoverySwipe:
        return -1.5; // immediate swipe away in Discovery
      case SignalType.skip:
        final secondsListened = event.value ?? 0;
        if (secondsListened < 10) return -3.0; // immediate skip
        if (secondsListened < 30) return -1.5; // short skip
        return -0.5; // late skip
    }
  }
}

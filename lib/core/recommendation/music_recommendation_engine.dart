// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicRecommendationEngine (user-taste → candidates → rank → diversity
// → exploration). MUSIC INTELLIGENCE V3.
// ═════════════════════════════════════════════════════════════════════════════
//
// Consumes the existing SignalStore/TasteProfile/repository (no duplication)
// and produces ranked, diversified, exploration-mixed music for Home/Discovery.
// Playback is untouched: the engine returns track maps, which feed the
// EXISTING VShotsPlaybackManager via playTrack().
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math';

import '../music/music_candidate.dart';
import '../music/music_candidate_generator.dart';
import '../music/music_diversity.dart';
import '../music/music_exploration.dart';
import '../music/music_validator.dart';
import '../providers/music_repository.dart';
import 'music_recommendation_config.dart';
import 'music_recommendation_context.dart';
import 'music_seen_store.dart';
import 'music_session_state.dart';
import 'music_user_profile.dart';
import 'music_user_profile_builder.dart';

class MusicRecommendationEngine {
  MusicRecommendationEngine({
    required MusicSearch search,
    MusicSeenStore? seenStore,
    MusicSessionState? session,
    MusicRecommendationConfig config = MusicRecommendationConfig.defaultConfig,
  })  : _generator = MusicCandidateGenerator(search: search, config: config),
        config = config,
        _seenStore = seenStore ?? MusicSeenStore(),
        _session = session ?? MusicSessionState();

  factory MusicRecommendationEngine.withRepository(
    MusicRepository repository, {
    MusicSeenStore? seenStore,
    MusicSessionState? session,
  }) =>
      MusicRecommendationEngine(
        search: (query, {required limit, excludeIds = const {}}) =>
            repository.search(query, limit: limit, excludeIds: excludeIds),
        seenStore: seenStore,
        session: session,
      );

  final MusicCandidateGenerator _generator;
  final MusicRecommendationConfig config;
  final MusicSeenStore _seenStore;
  final MusicSessionState _session;
  bool _seenReady = false;

  static const MusicContentValidator _validator = MusicContentValidator();

  /// Generates a personalized "For You" list (user taste → candidate pools →
  /// scoring → diversity → exploration → dedupe → seen penalty).
  Future<List<Map<String, dynamic>>> generateForYou({
    required Set<String> excludeIds,
    int count = 12,
    List<String> languages = const [],
    List<String> moods = const [],
    List<String> regions = const [],
  }) async {
    if (!_seenReady) {
      await _seenStore.initialize();
      _seenReady = true;
    }
    _session.requestToken++;
    final context = MusicRecommendationContext(
      mode: 'for_you',
      languages: languages,
      moods: moods,
      regions: regions,
      count: count,
      excludeIds: excludeIds,
      seenStore: _seenStore,
      session: _session,
    );

    final profile = MusicUserProfileBuilder(config: config).build();
    final candidates = await _generator.generate(
      profile: profile,
      context: context,
    );

    final artistCounts = <String, int>{};
    final scored = <ScoredMusicCandidate>[];
    for (final candidate in candidates) {
      final score = scoreForYou(
        candidate: candidate,
        profile: profile,
        context: context,
        artistCounts: artistCounts,
        config: config,
      );
      scored.add(ScoredMusicCandidate(candidate: candidate, score: score));
      artistCounts[candidate.artist] =
          (artistCounts[candidate.artist] ?? 0) + 1;
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final diversified = const MusicDiversity().diversify(scored);

    // Guarantee the configured exploration share (never 0 even if scores
    // bury it).
    final primary =
        diversified.where((s) => s.candidate.source != 'exploration').toList();
    final exploration =
        diversified.where((s) => s.candidate.source == 'exploration').toList();
    final mixed = MusicExploration(
      ratio: config.explorationRatio,
    ).mix(primary, exploration);

    final result = <Map<String, dynamic>>[];
    for (final s in mixed) {
      final c = s.candidate;
      if (!_session.emitSong(c.songId, c.track.id)) continue;
      result.add(c.track.toTrackMap());
      unawaited(_seenStore.record(c.songId));
      if (result.length >= count) break;
    }
    return result;
  }
}

/// The For You score. Every feature is normalized to 0..1 BEFORE weighting.
/// All weights come from [config]. Uses real signals only — unknown features
/// resolve to a neutral value, never a fabricated score.
double scoreForYou({
  required MusicCandidate candidate,
  required MusicUserProfile profile,
  required MusicRecommendationContext context,
  required Map<String, int> artistCounts,
  MusicRecommendationConfig config = MusicRecommendationConfig.defaultConfig,
}) {
  final track = candidate.track;
  final validation =
      MusicRecommendationEngine._validator.validate(track.toTrackMap());

  final artistAffinity = min(
    1.0,
    (profile.artistAffinity[candidate.artist] ?? 0) / 10.0,
  );
  final songAffinity = min(
    1.0,
    (profile.songAffinity[candidate.songId] ?? 0) / 5.0,
  );
  final genreAffinity = candidate.genre.isNotEmpty
      ? min(1.0, (profile.genreAffinity[candidate.genre] ?? 0) / 10.0)
      : 0.0;
  final languageAffinity = candidate.language.isNotEmpty
      ? min(1.0, (profile.languageAffinity[candidate.language] ?? 0) / 10.0)
      : 0.0;
  final moodAffinity = context.moods.isNotEmpty ? 0.5 : 0.0;
  const albumAffinity = 0.0; // no album signal in the pipeline (honest)

  final age = track.publishedDaysAgo;
  final recency = age == null ? 0.5 : 1.0 / (1.0 + age / 30.0);
  final quality = validation.confidence.clamp(0.0, 1.0);
  final officiality = validation.officialityScore.clamp(0.0, 1.0);
  final freshness = age == null ? 0.4 : 1.0 / (1.0 + age / 7.0);
  final novelty = 1.0 - artistAffinity; // unknown artists are more novel
  final popularity = track.viewCount == null
      ? 0.3
      : min(1.0, log(1 + track.viewCount!) / log(1 + 1000000000));

  final seenPenalty = context.seenStore.penalty(candidate.songId);
  final skipPenalty = min(
    1.0,
    (profile.artistSkipPenalty[candidate.artist] ?? 0) / 5.0,
  );
  final repetitionPenalty = min(
    1.0,
    (artistCounts[candidate.artist] ?? 0) / 5.0,
  );

  return artistAffinity * config.wArtist +
      songAffinity * config.wSong +
      genreAffinity * config.wGenre +
      languageAffinity * config.wLanguage +
      moodAffinity * config.wMood +
      albumAffinity * config.wAlbum +
      recency * config.wRecency +
      quality * config.wQuality +
      officiality * config.wOfficiality +
      freshness * config.wFreshness +
      novelty * config.wNovelty +
      popularity * config.wPopularity -
      seenPenalty * config.wSeenPenalty -
      skipPenalty * config.wSkipPenalty -
      repetitionPenalty * config.wRepetitionPenalty;
}

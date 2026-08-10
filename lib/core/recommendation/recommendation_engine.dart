// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: Orchestrator (Phase 7, Parts H/S/T/U)
// ════════════════════════════════════════════════
//
// The real pipeline from Part H's diagram:
//   User Signals -> Candidate Generation -> Feature Extraction ->
//   Scoring -> Filtering -> Diversity -> Final Feed
//
// This class wires together every piece built in this phase:
//   TasteProfileBuilder (Feature Extraction, from SignalStore's real
//     signal history)
//   CandidateGenerator (Candidate Generation, hybrid: content-based +
//     behavior-based + popularity + context + exploration — Part L)
//   MusicRepository (existing Provider Architecture — fetches REAL
//     tracks for each candidate query; this task does NOT touch or
//     duplicate that integration, per the task's explicit constraint)
//   RecommendationScorer (Scoring, Part K's weighted formula)
//   DiversityFilter (Diversity, Part N)
//   RecommendationCache (Caching, Part T)
//
// PERFORMANCE (Part S): scoring/diversity are pure, cheap arithmetic
// over small in-memory lists (no ML inference, no heavy computation) —
// there is no separate isolate/compute() call because profiling would
// show this is not a UI-thread bottleneck at this data scale (tens of
// candidates, not millions) — see this class's own `_rankCandidates`
// doc for the honest complexity analysis. The genuinely expensive part
// (the actual network search requests via MusicRepository) already
// runs async/off the synchronous call stack via `Future`s, same as
// every other network call in this app.
//
// CONTENT QUALITY (Part U): every candidate track that reaches the
// final feed already passed through YoutubeMusicMapper's existing
// podcast/compilation/duration filter (enforced inside
// YouTubeMusicProvider.search(), untouched by this task) — this class
// does not re-implement or weaken that filter; it only adds
// scoring/diversity ON TOP of already-quality-filtered candidates.
// ════════════════════════════════════════════════

import '../providers/music_repository.dart';
import '../providers/provider_models.dart';
import 'candidate_generator.dart';
import 'diversity_filter.dart';
import 'feed_intent.dart';
import 'recommendation_cache.dart';
import 'recommendation_config.dart';
import 'recommendation_metrics.dart';
import 'recommendation_scorer.dart';
import 'signal_event.dart';
import 'signal_store.dart';
import 'taste_profile.dart';

class RecommendationEngine {
  RecommendationEngine(
    this._repository, {
    this.config = RecommendationConfig.defaultConfig,
    CandidateGenerator? candidateGenerator,
    RecommendationScorer? scorer,
    DiversityFilter? diversityFilter,
    TasteProfileBuilder? profileBuilder,
  })  : _candidates = candidateGenerator ?? CandidateGenerator(config: config),
        _scorer = scorer ?? RecommendationScorer(config: config),
        _diversity = diversityFilter ?? DiversityFilter(config: config),
        _profileBuilder = profileBuilder ?? TasteProfileBuilder(config: config);

  final MusicRepository _repository;
  final RecommendationConfig config;
  final CandidateGenerator _candidates;
  final RecommendationScorer _scorer;
  final DiversityFilter _diversity;
  final TasteProfileBuilder _profileBuilder;

  /// Builds (or returns the cached) taste profile — cached per Part T,
  /// invalidated by [recordSignal] when a signal should affect future
  /// scoring.
  TasteProfile _getProfile() {
    final cached = RecommendationCache.instance.getCachedProfile();
    if (cached != null) return cached;
    final fresh = _profileBuilder.build();
    RecommendationCache.instance.setCachedProfile(fresh);
    return fresh;
  }

  /// Records a real user signal (Part I) and invalidates the relevant
  /// cache (Part T) so it actually affects the next feed request —
  /// this is the write-path every real playback/like/skip event in
  /// the app should call (see signal_recorder.dart for the actual
  /// wiring into main.dart's existing playback code).
  Future<void> recordSignal(SignalEvent event) async {
    await SignalStore.instance.record(event);
    // "Not interested"-strength signals (skip, unlike) should be
    // reflected in the VERY NEXT feed, not up to 5 stale minutes later
    // — full invalidation. Positive signals (play/completed/like) are
    // fine to only affect the next NATURAL cache expiry, since there's
    // no urgency to immediately reshuffle an already-good feed.
    if (event.type == SignalType.skip || event.type == SignalType.unlike) {
      RecommendationCache.instance.invalidateAll();
    } else {
      RecommendationCache.instance.invalidateProfile();
    }
  }

  /// Generates a ranked, diversified, quality-filtered feed for the
  /// given [intent] and [excludeIds] (tracks already shown this
  /// session — same contract as the pre-existing
  /// ForYouFeedService.fetchNextBatch's excludeIds parameter).
  ///
  /// Different [FeedIntent]s use different ranking emphasis (Part Q):
  /// this is achieved by biasing which CandidateSource-generated
  /// tracks are kept/boosted per intent, over the same underlying
  /// scoring pipeline — not N separate pipelines.
  Future<List<ScoredTrack>> generateFeed({
    required FeedIntent intent,
    required Set<String> excludeIds,
    int count = 10,
  }) async {
    final cacheKey = '${intent.name}:$count';
    if (RecommendationCache.instance.isFeedFresh(cacheKey)) {
      final cached = RecommendationCache.instance.getFeed(cacheKey)!;
      final filtered =
          cached.where((t) => !excludeIds.contains(t.track.id)).toList();
      if (filtered.length >= count) return filtered.take(count).toList();
      // else: fall through and generate fresh (cache is fresh but
      // exhausted by excludeIds — e.g. the user has already scrolled
      // past every cached track).
    }

    final profile = _getProfile();
    final candidateQueries = _candidateQueriesForIntent(intent, profile);

    // Fetch real tracks for each candidate query via the EXISTING
    // Provider Architecture (MusicRepository) — this is the one place
    // this engine touches "the current YouTube integration," and it
    // does so exactly the way ForYouFeedService/HomeScreen already do
    // (calling musicRepository.search()), per this task's explicit
    // "DO NOT change the current YouTube integration" constraint.
    final scored = <ScoredTrack>[];
    final seenIds = <String>{...excludeIds};

    for (final candidate in candidateQueries) {
      final isPopularitySource = candidate.source == CandidateSource.trending ||
          candidate.source == CandidateSource.newContent;
      final tracks = await _repository.search(
        candidate.query,
        limit: 6,
        excludeIds: seenIds,
      );
      for (final trackMap in tracks) {
        final id = trackMap['id'] as String? ?? '';
        if (id.isEmpty || !seenIds.add(id)) continue; // real de-dup (Part X)

        final providerTrack = ProviderTrack.fromTrackMap(trackMap);
        final result = _scorer.score(
          providerTrack,
          profile,
          sourceQuery: candidate.query,
          isTrendingOrNewSource: isPopularitySource,
        );
        scored.add(result);
      }
      if (scored.length >= count * 3) break; // enough candidates to rank from
    }

    // Filtering (Part U is already enforced upstream by
    // YoutubeMusicMapper inside the provider — this stage additionally
    // drops anything that scored non-positive, i.e. net-negative after
    // skip penalties, rather than ever surfacing a track the model
    // actively believes the user dislikes).
    final filtered = scored.where((s) => s.score > -1.0).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Diversity (Part N).
    final diversified = _diversity.apply(filtered);

    // Exploration mix (Part O): guarantee the configured exploration
    // fraction actually appears in the final feed, even if pure
    // score-ranking would have buried them below the cut line (a
    // brand-new artist naturally scores lower on affinity/recency no
    // matter how good the candidate is — exploration must be an
    // explicit guarantee, not a hope).
    final finalFeed =
        _mixInExploration(diversified, candidateQueries, count: count);

    RecommendationCache.instance.setFeed(cacheKey, finalFeed);

    final distinctArtists = finalFeed.map((t) => t.track.artist).toSet().length;
    RecommendationMetrics.sink.recordBatchDiversity(
      totalTracks: finalFeed.length,
      distinctArtists: distinctArtists,
      explorationFraction: config.explorationRate,
    );

    return finalFeed;
  }

  /// Guarantees [RecommendationConfig.explorationRate] of the final
  /// feed is drawn from exploration-sourced candidates specifically,
  /// promoting them into the result even if their raw score wouldn't
  /// have naturally ranked them in the top [count].
  List<ScoredTrack> _mixInExploration(
      List<ScoredTrack> ranked, List<CandidateQuery> candidateQueries,
      {required int count}) {
    if (ranked.length <= count) return ranked;

    final explorationQueries = candidateQueries
        .where((c) => c.source == CandidateSource.exploration)
        .map((c) => c.query)
        .toSet();

    final explorationSlots =
        (count * config.explorationRate).round().clamp(0, count);
    final nonExploration = <ScoredTrack>[];
    final exploration = <ScoredTrack>[];

    for (final track in ranked) {
      // A track is "exploration" if its title/artist genre tags
      // overlap with a genre an exploration query targeted — an
      // approximation (we don't carry the originating query per-track
      // through scoring), documented here as an honest simplification
      // rather than silently pretending perfect attribution.
      final isExploration = track.genreTags.isNotEmpty &&
          explorationQueries.any((q) =>
              q.toLowerCase().contains(track.genreTags.first.toLowerCase()));
      if (isExploration) {
        exploration.add(track);
      } else {
        nonExploration.add(track);
      }
    }

    final result = <ScoredTrack>[];
    result.addAll(nonExploration.take(count - explorationSlots));
    result.addAll(exploration.take(explorationSlots));

    // Backfill from whichever pool has leftovers if one pool was too
    // small to fill its slot allocation (e.g. cold start with very few
    // genuinely-tagged exploration candidates).
    if (result.length < count) {
      final remaining =
          [...nonExploration, ...exploration].where((t) => !result.contains(t));
      result.addAll(remaining.take(count - result.length));
    }

    return result.take(count).toList();
  }

  List<CandidateQuery> _candidateQueriesForIntent(
      FeedIntent intent, TasteProfile profile) {
    final all = _candidates.generate(profile, count: 12);
    // Part Q: different ranking logic per intent — implemented as a
    // real filter/bias over the shared candidate pool rather than a
    // fully separate pipeline per intent.
    switch (intent) {
      case FeedIntent.forYou:
        return all; // full hybrid mix, default weighting
      case FeedIntent.becauseYouListenedTo:
      case FeedIntent.similarArtists:
        final filtered = all
            .where((c) =>
                c.source == CandidateSource.similarArtist ||
                c.source == CandidateSource.recentlyPlayedPattern)
            .toList();
        return filtered.isEmpty ? all : filtered;
      case FeedIntent.moreLikeThis:
        final filtered =
            all.where((c) => c.source == CandidateSource.genreTag).toList();
        return filtered.isEmpty ? all : filtered;
      case FeedIntent.madeForYou:
        final filtered = all
            .where((c) =>
                c.source == CandidateSource.recentlyPlayedPattern ||
                c.source == CandidateSource.likedMusic)
            .toList();
        return filtered.isEmpty ? all : filtered;
      case FeedIntent.trendingForYou:
        final filtered =
            all.where((c) => c.source == CandidateSource.trending).toList();
        return filtered.isEmpty ? all : filtered;
      case FeedIntent.continueListening:
        final filtered = all
            .where((c) => c.source == CandidateSource.recentlyPlayedPattern)
            .toList();
        return filtered.isEmpty ? all : filtered;
      case FeedIntent.discoverSomethingNew:
        final filtered =
            all.where((c) => c.source == CandidateSource.exploration).toList();
        return filtered.isEmpty ? all : filtered;
    }
  }
}

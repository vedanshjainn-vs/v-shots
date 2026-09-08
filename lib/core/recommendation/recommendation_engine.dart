// ═════════════════════════════════════════════════════════════════════════
// V Shots — Recommendation Engine: Orchestrator (V2 Engine)
// ═════════════════════════════════════════════════════════════════════════

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

  TasteProfile _getProfile() {
    final cached = RecommendationCache.instance.getCachedProfile();
    if (cached != null) return cached;
    final fresh = _profileBuilder.build();
    RecommendationCache.instance.setCachedProfile(fresh);
    return fresh;
  }

  Future<void> recordSignal(SignalEvent event) async {
    await SignalStore.instance.record(event);
    if (event.type == SignalType.skip || event.type == SignalType.unlike) {
      RecommendationCache.instance.invalidateAll();
    } else {
      RecommendationCache.instance.invalidateProfile();
    }
  }

  Future<List<ScoredTrack>> generateFeed({
    required FeedIntent intent,
    required Set<String> excludeIds,
    int count = 10,
    bool forceRefresh = false,
    String? seedTrackId,
  }) async {
    // "More Like This" with seed track uses related endpoint
    if (intent == FeedIntent.moreLikeThis &&
        seedTrackId != null &&
        seedTrackId.isNotEmpty) {
      final related = await _generateRelatedFeed(
        seedTrackId: seedTrackId,
        excludeIds: excludeIds,
        count: count,
        forceRefresh: forceRefresh,
      );
      if (related.isNotEmpty) return related;
    }

    final cacheKey = '${intent.name}:$count';
    if (!forceRefresh && RecommendationCache.instance.isFeedFresh(cacheKey)) {
      final cached = RecommendationCache.instance.getFeed(cacheKey)!;
      final filtered =
          cached.where((t) => !excludeIds.contains(t.track.id)).toList();
      if (filtered.length >= count) return filtered.take(count).toList();
    }

    final profile = _getProfile();

    // Cold start rule: "Because You Listened To" is hidden when cold
    if (intent == FeedIntent.becauseYouListenedTo &&
        !profile.hasEnoughHistoryForPersonalization) {
      return const [];
    }

    final candidateQueries = _candidateQueriesForIntent(intent, profile);
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
        if (id.isEmpty || !seenIds.add(id)) continue;

        final providerTrack = ProviderTrack.fromTrackMap(trackMap);
        final result = _scorer.score(
          providerTrack,
          profile,
          sourceQuery: candidate.query,
          isTrendingOrNewSource: isPopularitySource,
        );
        scored.add(result);
      }
      if (scored.length >= count * 3) break;
    }

    // Filter net-negative tracks
    final filtered = scored.where((s) => s.score > -1.0).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Apply diversity rules
    final diversified = _diversity.apply(filtered);

    // Controlled exploration mix
    final finalFeed = _mixInExploration(
      diversified,
      candidateQueries,
      count: count,
    );

    RecommendationCache.instance.setFeed(cacheKey, finalFeed);

    final distinctArtists = finalFeed.map((t) => t.track.artist).toSet().length;
    RecommendationMetrics.sink.recordBatchDiversity(
      totalTracks: finalFeed.length,
      distinctArtists: distinctArtists,
      explorationFraction: config.explorationRate,
    );

    return finalFeed;
  }

  Future<List<ScoredTrack>> _generateRelatedFeed({
    required String seedTrackId,
    required Set<String> excludeIds,
    required int count,
    required bool forceRefresh,
  }) async {
    final cacheKey = 'related:$seedTrackId:$count';
    if (!forceRefresh && RecommendationCache.instance.isFeedFresh(cacheKey)) {
      final cached = RecommendationCache.instance.getFeed(cacheKey)!;
      final filtered =
          cached.where((t) => !excludeIds.contains(t.track.id)).toList();
      if (filtered.length >= count) return filtered.take(count).toList();
    }

    final profile = _getProfile();
    final tracks = await _repository.getRelated(seedTrackId, limit: count * 3);

    final scored = <ScoredTrack>[];
    final seenIds = <String>{seedTrackId, ...excludeIds};
    for (final trackMap in tracks) {
      final id = trackMap['id'] as String? ?? '';
      if (id.isEmpty || !seenIds.add(id)) continue;

      final providerTrack = ProviderTrack.fromTrackMap(trackMap);
      final result = _scorer.score(
        providerTrack,
        profile,
        sourceQuery: null,
        isTrendingOrNewSource: false,
      );
      scored.add(result);
    }

    final filtered = scored.where((s) => s.score > -1.0).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final diversified = _diversity.apply(filtered);
    final finalFeed = diversified.take(count).toList();

    RecommendationCache.instance.setFeed(cacheKey, finalFeed);

    final distinctArtists = finalFeed.map((t) => t.track.artist).toSet().length;
    RecommendationMetrics.sink.recordBatchDiversity(
      totalTracks: finalFeed.length,
      distinctArtists: distinctArtists,
      explorationFraction: 0,
    );

    return finalFeed;
  }

  List<ScoredTrack> _mixInExploration(
    List<ScoredTrack> ranked,
    List<CandidateQuery> candidateQueries, {
    required int count,
  }) {
    if (ranked.length <= count) return ranked;

    final explorationQueries = candidateQueries
        .where((c) => c.source == CandidateSource.exploration)
        .map((c) => c.query)
        .toSet();

    final explorationSlots = (count * config.explorationRate).round().clamp(
          0,
          count,
        );
    final nonExploration = <ScoredTrack>[];
    final exploration = <ScoredTrack>[];

    for (final track in ranked) {
      final isExploration = track.genreTags.isNotEmpty &&
          explorationQueries.any(
            (q) =>
                q.toLowerCase().contains(track.genreTags.first.toLowerCase()),
          );
      if (isExploration) {
        exploration.add(track);
      } else {
        nonExploration.add(track);
      }
    }

    final result = <ScoredTrack>[];
    result.addAll(nonExploration.take(count - explorationSlots));
    result.addAll(exploration.take(explorationSlots));

    if (result.length < count) {
      final remaining = [
        ...nonExploration,
        ...exploration,
      ].where((t) => !result.contains(t));
      result.addAll(remaining.take(count - result.length));
    }

    return result.take(count).toList();
  }

  List<CandidateQuery> _candidateQueriesForIntent(
    FeedIntent intent,
    TasteProfile profile,
  ) {
    final all = _candidates.generate(profile, count: 12);
    switch (intent) {
      case FeedIntent.forYou:
        return all;
      case FeedIntent.becauseYouListenedTo:
      case FeedIntent.similarArtists:
        final filtered = all
            .where(
              (c) =>
                  c.source == CandidateSource.similarArtist ||
                  c.source == CandidateSource.recentlyPlayedPattern,
            )
            .toList();
        return filtered.isEmpty ? all : filtered;
      case FeedIntent.moreLikeThis:
        final filtered =
            all.where((c) => c.source == CandidateSource.genreTag).toList();
        return filtered.isEmpty ? all : filtered;
      case FeedIntent.madeForYou:
        final filtered = all
            .where(
              (c) =>
                  c.source == CandidateSource.searchBehavior ||
                  c.source == CandidateSource.recentlyPlayedPattern ||
                  c.source == CandidateSource.likedMusic,
            )
            .toList();
        return filtered.isEmpty ? all : filtered;
      case FeedIntent.quickPicks:
        final filtered = all
            .where(
              (c) =>
                  c.source == CandidateSource.searchBehavior ||
                  c.source == CandidateSource.recentlyPlayedPattern,
            )
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
        final filtered = all
            .where(
              (c) =>
                  c.source == CandidateSource.exploration ||
                  c.source == CandidateSource.newContent,
            )
            .toList();
        return filtered.isEmpty ? all : filtered;
    }
  }
}

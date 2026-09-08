import 'package:flutter_test/flutter_test.dart';

import 'package:v_shots/core/music/music_candidate.dart';
import 'package:v_shots/core/providers/provider_models.dart';
import 'package:v_shots/core/recommendation/advanced_recommendation_v2.dart';
import 'package:v_shots/core/recommendation/music_recommendation_context.dart';
import 'package:v_shots/core/recommendation/music_seen_store.dart';
import 'package:v_shots/core/recommendation/taste_profile.dart';

MusicCandidate candidate({
  required String id,
  required String artist,
  String genre = 'Bollywood',
  String language = 'hindi',
  String source = 'favorite_artist',
  String? seedArtist,
}) {
  return MusicCandidate(
    track: ProviderTrack(
      id: id,
      title: '$artist song',
      artist: artist,
      artworkUrl: '',
      durationSeconds: 180,
      isOfficial: true,
      publishedDaysAgo: 2,
    ),
    songId: id,
    source: source,
    seedArtist: seedArtist,
    artist: artist,
    genre: genre,
    language: language,
  );
}

TasteProfile profile({
  TasteMaturity maturity = TasteMaturity.confident,
  Map<String, double> artists = const {'Artist A': 8},
  Map<String, double> genres = const {'Bollywood': 8},
  Map<String, double> languages = const {'hindi': 8},
  Map<String, double> searches = const {},
  Map<String, double> skips = const {},
  Map<String, double> negative = const {},
  Map<String, double> completion = const {'Artist A': 0.9},
  Map<String, double> replay = const {'Artist A': 0.4},
  Set<String> shortArtists = const {'Artist A'},
}) {
  return TasteProfile(
    artistAffinity: artists,
    genreAffinity: genres,
    languageAffinity: languages,
    moodAffinity: const {},
    searchAffinity: searches,
    playlistAffinity: const {},
    songAffinity: const {},
    artistSkipPenalty: skips,
    artistCompletionRate: completion,
    artistRepeatRate: replay,
    negativeTaste: negative,
    confidenceScores: const {
      'artist': 0.9,
      'genre': 0.9,
      'language': 0.9,
      'search': 0.8,
      'overall': 0.9,
    },
    maturity: maturity,
    shortTermArtists: shortArtists,
    shortTermGenres: const {'Bollywood'},
    longTermArtists: {'Artist A'},
    longTermGenres: const {'Bollywood'},
    totalSignalCount: 40,
  );
}

MusicRecommendationContext context() => MusicRecommendationContext(
      mode: 'test',
      count: 10,
      seenStore: MusicSeenStore(),
    );

void main() {
  test('cold profile does not receive a personalization boost', () {
    final cold = profile(maturity: TasteMaturity.cold);
    final personalized = candidate(id: 'a', artist: 'Artist A');
    final score = AdvancedRecommendationV2.score(
      candidate: personalized,
      profile: cold,
      shelf: RecommendationShelf.madeForYou,
      context: context(),
      artistCounts: const {},
      candidateIndex: 0,
    );
    final unknown = candidate(
      id: 'b',
      artist: 'Unknown',
      source: 'trending',
    );
    final broad = AdvancedRecommendationV2.score(
      candidate: unknown,
      profile: cold,
      shelf: RecommendationShelf.madeForYou,
      context: context(),
      artistCounts: const {},
      candidateIndex: 1,
    );
    expect(score, lessThan(broad));
  });

  test('explicit search increases relevance for matching artist', () {
    final p = profile(searches: const {'Artist A': 6});
    final match = AdvancedRecommendationV2.score(
      candidate: candidate(id: 'a', artist: 'Artist A'),
      profile: p,
      shelf: RecommendationShelf.madeForYou,
      context: context(),
      artistCounts: const {},
      candidateIndex: 0,
    );
    final other = AdvancedRecommendationV2.score(
      candidate: candidate(id: 'b', artist: 'Artist B', source: 'trending'),
      profile: p,
      shelf: RecommendationShelf.madeForYou,
      context: context(),
      artistCounts: const {},
      candidateIndex: 1,
    );
    expect(match, greaterThan(other));
  });

  test('repeated skip produces a stronger penalty than no skip', () {
    final skipped = profile(skips: const {'Artist B': 5}, negative: const {'Artist B': 5});
    final score = AdvancedRecommendationV2.score(
      candidate: candidate(id: 'b', artist: 'Artist B', source: 'trending'),
      profile: skipped,
      shelf: RecommendationShelf.trendingForYou,
      context: context(),
      artistCounts: const {},
      candidateIndex: 0,
    );
    final clean = AdvancedRecommendationV2.score(
      candidate: candidate(id: 'b2', artist: 'Artist B', source: 'trending'),
      profile: profile(),
      shelf: RecommendationShelf.trendingForYou,
      context: context(),
      artistCounts: const {},
      candidateIndex: 0,
    );
    expect(score, lessThan(clean));
  });

  test('because-you-listened rewards causal seed artist', () {
    final p = profile();
    final causal = AdvancedRecommendationV2.score(
      candidate: candidate(
        id: 'a',
        artist: 'Artist B',
        source: 'similar_artist',
        seedArtist: 'Artist A',
      ),
      profile: p,
      shelf: RecommendationShelf.becauseYouListenedTo,
      context: context(),
      artistCounts: const {},
      candidateIndex: 0,
    );
    final unrelated = AdvancedRecommendationV2.score(
      candidate: candidate(id: 'b', artist: 'Artist C', source: 'exploration'),
      profile: p,
      shelf: RecommendationShelf.becauseYouListenedTo,
      context: context(),
      artistCounts: const {},
      candidateIndex: 1,
    );
    expect(causal, greaterThan(unrelated));
  });

  test('shelf reason is deterministic and machine-readable', () {
    final c = candidate(id: 'a', artist: 'Artist A');
    final r = AdvancedRecommendationV2.reason(
      candidate: c,
      profile: profile(),
      shelf: RecommendationShelf.madeForYou,
    );
    expect(r, 'because_recently_played_artist');
  });
}

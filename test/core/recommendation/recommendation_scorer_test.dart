// ════════════════════════════════════════════════
// V Shots — RecommendationScorer tests (Phase 7, Part X)
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/providers/provider_models.dart';
import 'package:v_shots/core/recommendation/recommendation_scorer.dart';
import 'package:v_shots/core/recommendation/signal_event.dart';
import 'package:v_shots/core/recommendation/signal_store.dart';
import 'package:v_shots/core/recommendation/taste_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SignalStore.instance.initialize();
    await SignalStore.instance.clear();
  });

  const track = ProviderTrack(
    id: 'x1',
    title: 'Some Song',
    artist: 'Known Artist',
    artworkUrl: '',
    durationSeconds: 200,
  );

  test('a track from a high-affinity artist scores higher than a neutral one',
      () {
    final scorer = RecommendationScorer();
    const highAffinityProfile = TasteProfile(
      artistAffinity: {'Known Artist': 5.0},
      genreAffinity: {},
      artistSkipPenalty: {},
      totalSignalCount: 5,
    );
    const neutralProfile = TasteProfile.empty;

    final highScore = scorer.score(track, highAffinityProfile,
        sourceQuery: null, isTrendingOrNewSource: false);
    final neutralScore = scorer.score(track, neutralProfile,
        sourceQuery: null, isTrendingOrNewSource: false);

    expect(highScore.score, greaterThan(neutralScore.score));
  });

  test('skip penalty lowers the score for that artist', () {
    final scorer = RecommendationScorer();
    const withSkipPenalty = TasteProfile(
      artistAffinity: {'Known Artist': 2.0},
      genreAffinity: {},
      artistSkipPenalty: {'Known Artist': 3.0},
      totalSignalCount: 5,
    );
    const withoutSkipPenalty = TasteProfile(
      artistAffinity: {'Known Artist': 2.0},
      genreAffinity: {},
      artistSkipPenalty: {},
      totalSignalCount: 5,
    );

    final penalized = scorer.score(track, withSkipPenalty,
        sourceQuery: null, isTrendingOrNewSource: false);
    final clean = scorer.score(track, withoutSkipPenalty,
        sourceQuery: null, isTrendingOrNewSource: false);

    expect(penalized.score, lessThan(clean.score));
  });

  test('trending/new-content source gets a popularity boost', () {
    final scorer = RecommendationScorer();
    const profile = TasteProfile.empty;
    final trending = scorer.score(track, profile,
        sourceQuery: null, isTrendingOrNewSource: true);
    final nonTrending = scorer.score(track, profile,
        sourceQuery: null, isTrendingOrNewSource: false);
    expect(trending.score, greaterThan(nonTrending.score));
  });

  test('novelty is high for an artist with zero affinity', () {
    final scorer = RecommendationScorer();
    final result = scorer.score(track, TasteProfile.empty,
        sourceQuery: null, isTrendingOrNewSource: false, debug: true);
    expect(result.debugBreakdown!['novelty'], 1.0);
  });

  test('completion probability defaults to a neutral 0.5 with no history', () {
    final scorer = RecommendationScorer();
    final result = scorer.score(track, TasteProfile.empty,
        sourceQuery: null, isTrendingOrNewSource: false, debug: true);
    expect(result.debugBreakdown!['completionProbability'], 0.5);
  });

  test(
      'completion probability reflects real completed-vs-skip history for that artist',
      () async {
    final now = DateTime.now();
    await SignalStore.instance.record(SignalEvent(
        type: SignalType.completed,
        timestamp: now,
        artist: 'Known Artist',
        trackId: 'a'));
    await SignalStore.instance.record(SignalEvent(
        type: SignalType.completed,
        timestamp: now,
        artist: 'Known Artist',
        trackId: 'b'));
    await SignalStore.instance.record(SignalEvent(
        type: SignalType.skip,
        timestamp: now,
        artist: 'Known Artist',
        trackId: 'c',
        value: 2));

    final scorer = RecommendationScorer();
    final result = scorer.score(track, TasteProfile.empty,
        sourceQuery: null, isTrendingOrNewSource: false, debug: true);
    // 2 completions out of 3 relevant events = 0.666...
    expect(
        result.debugBreakdown!['completionProbability'], closeTo(2 / 3, 0.01));
  });

  test(
      'genre similarity contributes when candidate tags overlap user top genres',
      () {
    final scorer = RecommendationScorer();
    const profile = TasteProfile(
      artistAffinity: {},
      genreAffinity: {'Punjabi': 5.0},
      artistSkipPenalty: {},
      totalSignalCount: 5,
    );
    const punjabiTrack = ProviderTrack(
      id: 'p1',
      title: 'Punjabi Anthem',
      artist: 'Some Artist',
      artworkUrl: '',
      durationSeconds: 180,
    );
    final result = scorer.score(punjabiTrack, profile,
        sourceQuery: 'punjabi hit songs',
        isTrendingOrNewSource: false,
        debug: true);
    expect(result.debugBreakdown!['similarity'], greaterThan(0));
  });
}

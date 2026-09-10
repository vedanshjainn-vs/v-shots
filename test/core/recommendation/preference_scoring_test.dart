// ═════════════════════════════════════════════════════════════════════════════
// V Shots — stated-preference scoring tests (Batch 5: Home/Discovery
// personalization). Covers PreferenceSnapshot matchers, the scoreForYou
// preference features, and preference-aware Home shelf reordering.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/providers/provider_models.dart';
import 'package:v_shots/core/music/music_candidate.dart';
import 'package:v_shots/core/recommendation/music_recommendation_config.dart';
import 'package:v_shots/core/recommendation/music_recommendation_context.dart';
import 'package:v_shots/core/recommendation/music_recommendation_engine.dart';
import 'package:v_shots/core/recommendation/music_user_profile.dart';
import 'package:v_shots/core/recommendation/preference_scoring.dart';
import 'package:v_shots/core/storage/personalization_store.dart';
import 'package:v_shots/features/home/home_feed_service.dart';

ProviderTrack _track(String id, String title, String artist) => ProviderTrack(
      id: id,
      title: title,
      artist: artist,
      artworkUrl: '',
      durationSeconds: 200,
      isOfficial: true,
    );

MusicUserProfile get _emptyProfile => const MusicUserProfile(
      artistAffinity: {},
      genreAffinity: {},
      languageAffinity: {},
      moodAffinity: {},
      albumAffinity: {},
      songAffinity: {},
      artistSkipPenalty: {},
      recentArtists: [],
      recentSongs: [],
    );

Future<void> _setPrefs({
  List<String> languages = const [],
  List<String> genres = const [],
  List<String> artists = const [],
  List<FavoriteSong> songs = const [],
}) async {
  final store = PersonalizationStore.instance;
  await store.reset();
  await store.updatePreferences(
    languages: languages,
    genres: genres,
    artists: artists,
    songs: songs,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PersonalizationStore.instance.initialize();
    await PersonalizationStore.instance.reset();
  });

  group('PreferenceSnapshot matchers', () {
    test('empty store → empty snapshot, all matchers neutral', () async {
      final snap = PreferenceSnapshot.capture();
      expect(snap.isEmpty, isTrue);
      expect(snap.languageMatch('Hindi'), 0.0);
      expect(snap.artistMatch('Arijit Singh'), 0.0);
      expect(snap.genreMatch('Romantic'), 0.0);
      expect(snap.songMatch(title: 'Kesariya', artist: 'Arijit Singh'), 0.0);
    });

    test('language match is normalized (case/whitespace insensitive)',
        () async {
      await _setPrefs(languages: ['Hindi', 'Punjabi']);
      final snap = PreferenceSnapshot.capture();
      expect(snap.languageMatch('Hindi'), 1.0);
      expect(snap.languageMatch('  HINDI '), 1.0);
      expect(snap.languageMatch('Tamil'), 0.0);
      expect(snap.languageMatch(null), 0.0);
      expect(snap.languageMatch(''), 0.0);
    });

    test('artist match resolves collaborative credit strings', () async {
      await _setPrefs(artists: ['Arijit Singh', 'Shreya Ghoshal']);
      final snap = PreferenceSnapshot.capture();
      expect(snap.artistMatch('Arijit Singh'), 1.0);
      expect(snap.artistMatch('arijit   singh'), 1.0);
      expect(snap.artistMatch('Arijit Singh, Shreya Ghoshal'), 1.0);
      expect(snap.artistMatch('Arijit Singh ft. Badshah'), 1.0);
      expect(snap.artistMatch('Atif Aslam'), 0.0);
    });

    test('genre match normalizes punctuation (Lo-Fi / hip hop)', () async {
      await _setPrefs(genres: ['Lo-Fi', 'Hip-Hop']);
      final snap = PreferenceSnapshot.capture();
      expect(snap.genreMatch('Lo-Fi'), 1.0);
      expect(snap.genreMatch('lo fi'), 1.0);
      expect(snap.genreMatch('Hip-Hop'), 1.0);
      expect(snap.genreMatch('hip hop'), 1.0);
      expect(snap.genreMatch('EDM'), 0.0);
    });

    test('song match: exact key 1.0, title-only 0.5, miss 0', () async {
      await _setPrefs(songs: [
        const FavoriteSong(
          id: 'vid1',
          title: 'Kesariya',
          artist: 'Arijit Singh',
        ),
      ]);
      final snap = PreferenceSnapshot.capture();
      expect(
        snap.songMatch(title: 'Kesariya', artist: 'Arijit Singh'),
        1.0,
      );
      expect(snap.songMatch(title: 'Kesariya', artist: 'Sanam'), 0.5);
      expect(snap.songMatch(title: 'Raabta', artist: 'Arijit Singh'), 0.0);
    });

    test('queryTokens: languages first then genres, capped, re-cased',
        () async {
      await _setPrefs(
        languages: ['punjabi', 'tamil'],
        genres: ['Romantic', 'Rock', 'Indie'],
      );
      final snap = PreferenceSnapshot.capture();
      expect(snap.queryTokens(max: 3), ['Punjabi', 'Tamil', 'Romantic']);
    });
  });

  group('scoreForYou stated-preference features', () {
    test('stated favorite artist outranks an unknown artist at cold start',
        () async {
      final context = MusicRecommendationContext(mode: 'for_you');
      const config = MusicRecommendationConfig.defaultConfig;

      final preferred = MusicCandidate(
        track: _track('a1', 'Song A', 'Arijit Singh'),
        songId: 'a1',
        source: 'favorite_artist',
        artist: 'Arijit Singh',
        genre: 'Romantic',
        language: 'Hindi',
      );
      final other = MusicCandidate(
        track: _track('b1', 'Song B', 'Random Unknown Artist'),
        songId: 'b1',
        source: 'trending',
        artist: 'Random Unknown Artist',
        genre: 'EDM',
        language: 'English',
      );

      // No preferences: neutral baseline (other may even win via novelty).
      final before = scoreForYou(
        candidate: preferred,
        profile: _emptyProfile,
        context: context,
        artistCounts: const {},
        config: config,
      );
      final beforeOther = scoreForYou(
        candidate: other,
        profile: _emptyProfile,
        context: context,
        artistCounts: const {},
        config: config,
      );

      await _setPrefs(
        languages: ['Hindi'],
        genres: ['Romantic'],
        artists: ['Arijit Singh'],
      );
      final snap = PreferenceSnapshot.capture();

      final after = scoreForYou(
        candidate: preferred,
        profile: _emptyProfile,
        context: context,
        artistCounts: const {},
        config: config,
        preferences: snap,
      );
      final afterOther = scoreForYou(
        candidate: other,
        profile: _emptyProfile,
        context: context,
        artistCounts: const {},
        config: config,
        preferences: snap,
      );

      // The preferred candidate gains the full stated mass; the unknown
      // gains nothing; ranking flips (or widens) toward the preference.
      expect(
        after - before,
        closeTo(
          1.0 * config.wStatedArtist +
              1.0 * config.wStatedGenre +
              1.0 * config.wStatedLanguage,
          0.0001,
        ),
      );
      expect(afterOther - beforeOther, 0.0);
      expect(after, greaterThan(afterOther));
    });

    test('null snapshot leaves the score untouched (backward compatible)', () {
      final candidate = MusicCandidate(
        track: _track('c1', 'Song C', 'Neha Kakkar'),
        songId: 'c1',
        source: 'trending',
        artist: 'Neha Kakkar',
      );
      final a = scoreForYou(
        candidate: candidate,
        profile: _emptyProfile,
        context: MusicRecommendationContext(mode: 'for_you'),
        artistCounts: const {},
      );
      final b = scoreForYou(
        candidate: candidate,
        profile: _emptyProfile,
        context: MusicRecommendationContext(mode: 'for_you'),
        artistCounts: const {},
        preferences: null,
      );
      expect(a, b);
    });
  });

  group('Home shelf preference reordering', () {
    HomeShelf shelf(
      String id,
      String title,
      String query,
    ) =>
        HomeShelf(
          id: id,
          title: title,
          subtitle: '',
          kind: HomeShelfKind.catalog,
          query: query,
        );

    test('matching shelves float up, unmatched keep CMS order (stable)',
        () async {
      await _setPrefs(
        languages: ['Punjabi'],
        genres: ['Devotional'],
        artists: ['Diljit Dosanjh'],
      );
      final snap = PreferenceSnapshot.capture();

      final shelves = [
        shelf('s1', 'Top Hits Today', 'top hits official audio'),
        shelf('s2', 'Punjabi Hits 2026', 'punjabi hit songs official audio'),
        shelf('s3', 'Workout Energy', 'workout songs official audio'),
        shelf('s4', 'Diljit Dosanjh Radio', 'diljit dosanjh songs official'),
        shelf('s5', 'Devotional Mornings', 'devotional songs official audio'),
        shelf('s6', 'Indie Discoveries', 'indie songs official audio'),
      ];

      HomeFeedService.reorderShelvesByPreference(shelves, snap);

      // Artist match (weight 2) first, then language/genre matches (+1
      // each), unmatched shelves keep their relative CMS order.
      expect(shelves.first.id, 's4');
      expect(shelves[1].id, 's2'); // punjabi query + punjabi title = +2
      expect(shelves[2].id, 's5'); // devotional +1
      // Unmatched: s1 before s3 before s6 (original order preserved).
      final unmatchedIds = shelves.skip(3).map((s) => s.id).toList();
      expect(unmatchedIds, containsAll(['s1', 's3', 's6']));
      expect(unmatchedIds.indexOf('s1') < unmatchedIds.indexOf('s3'), isTrue);
      expect(unmatchedIds.indexOf('s3') < unmatchedIds.indexOf('s6'), isTrue);
    });

    test('empty preferences → strict no-op, order untouched', () async {
      final snap = PreferenceSnapshot.capture(); // empty
      final shelves = [
        shelf('a', 'A', 'a'),
        shelf('b', 'B', 'b'),
        shelf('c', 'C', 'c'),
      ];
      HomeFeedService.reorderShelvesByPreference(shelves, snap);
      expect(shelves.map((s) => s.id).toList(), ['a', 'b', 'c']);
    });

    test('equal scores stay in exact CMS order (true stability)', () async {
      await _setPrefs(genres: ['Rock']);
      final snap = PreferenceSnapshot.capture();
      final shelves = [
        shelf('x1', 'Rock Classics', 'rock classics official'),
        shelf('x2', 'Rock Ballads', 'rock ballads official'),
        shelf('x3', 'Rock Live', 'rock live official'),
        shelf('x4', 'Charts', 'top charts official'),
      ];
      HomeFeedService.reorderShelvesByPreference(shelves, snap);
      expect(shelves.map((s) => s.id).toList(), ['x1', 'x2', 'x3', 'x4']);
    });
  });
}

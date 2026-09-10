// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicRecommendationEngine tests (For You + dedupe + exclude)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/music/music_candidate_generator.dart';
import 'package:v_shots/core/recommendation/music_recommendation_engine.dart';
import 'package:v_shots/core/recommendation/music_seen_store.dart';
import 'package:v_shots/core/recommendation/music_session_state.dart';
import 'package:v_shots/core/recommendation/signal_event.dart';
import 'package:v_shots/core/recommendation/signal_store.dart';
import 'package:v_shots/core/storage/personalization_store.dart';

MusicSearch _fakeSearch() {
  return (query, {required limit, excludeIds = const {}}) async {
    final q = query.toLowerCase();
    final artist = q.contains('arijit')
        ? 'Arijit Singh'
        : q.contains('trending')
            ? 'Trending Artist'
            : 'Artist $q';
    return List.generate(limit, (i) {
      return {
        'id': 'vid-${query.hashCode}-$i',
        'title': '$artist Song $i',
        'artist': artist,
        'artwork': '',
        'duration': 200,
        'isOfficial': true,
      };
    }).where((m) => !excludeIds.contains(m['id'])).toList();
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SignalStore.instance.initialize();
    await SignalStore.instance.clear();
  });

  test('cold start returns a non-empty For You feed', () async {
    final engine = MusicRecommendationEngine(
      search: _fakeSearch(),
      seenStore: MusicSeenStore(),
      session: MusicSessionState(),
    );
    final feed = await engine.generateForYou(excludeIds: const {}, count: 10);
    expect(feed, isNotEmpty);
  });

  test('personalized feed surfaces the seeded artist', () async {
    await SignalStore.instance.record(
      SignalEvent(
        type: SignalType.like,
        timestamp: DateTime.now(),
        trackId: 'a1',
        artist: 'Arijit Singh',
        title: 'Tum Hi Ho',
      ),
    );
    final engine = MusicRecommendationEngine(
      search: _fakeSearch(),
      seenStore: MusicSeenStore(),
      session: MusicSessionState(),
    );
    final feed = await engine.generateForYou(excludeIds: const {}, count: 12);
    expect(
      feed.any((t) => t['artist'] == 'Arijit Singh'),
      isTrue,
      reason: 'the seeded favorite artist must be surfaced',
    );
  });

  test('dedupes duplicate canonical songs (same title+artist)', () async {
    Future<List<Map<String, dynamic>>> dupSearch(
      String query, {
      required int limit,
      Set<String> excludeIds = const {},
    }) async {
      // Return duplicate representations of the same song.
      return [
        {
          'id': 'v1',
          'title': 'Tum Hi Ho (Official Video)',
          'artist': 'Arijit Singh',
          'artwork': '',
          'duration': 200,
          'isOfficial': true,
        },
        {
          'id': 'v2',
          'title': 'Tum Hi Ho (Official Audio)',
          'artist': 'Arijit Singh',
          'artwork': '',
          'duration': 200,
          'isOfficial': true,
        },
        {
          'id': 'v3',
          'title': 'Other Song',
          'artist': 'B',
          'artwork': '',
          'duration': 200,
        },
      ];
    }

    final engine = MusicRecommendationEngine(
      search: dupSearch,
      seenStore: MusicSeenStore(),
      session: MusicSessionState(),
    );
    final feed = await engine.generateForYou(excludeIds: const {}, count: 6);
    final titles =
        feed.map((t) => (t['title'] as String).toLowerCase()).toList();
    expect(
      titles.where((t) => t.contains('tum hi ho')).length,
      1,
      reason: 'audio + video of the same song must dedupe to one',
    );
  });

  test('respects excludeIds', () async {
    final engine = MusicRecommendationEngine(
      search: _fakeSearch(),
      seenStore: MusicSeenStore(),
      session: MusicSessionState(),
    );
    final all = await engine.generateForYou(excludeIds: const {}, count: 12);
    final firstId = all.first['id'] as String;
    final again = await engine.generateForYou(excludeIds: {firstId}, count: 12);
    expect(again.any((t) => t['id'] == firstId), isFalse);
  });

  test('cold start seeds candidate pools from stated preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PersonalizationStore.instance;
    await store.initialize();
    await store.reset();
    await store.updatePreferences(
      languages: ['Punjabi'],
      genres: ['Romantic'],
      artists: ['Diljit Dosanjh', 'Arijit Singh'],
      songs: const [
        FavoriteSong(
          id: 'vid1',
          title: 'Lover',
          artist: 'Diljit Dosanjh',
        ),
      ],
    );

    // Record every query the generator issues.
    final issued = <String>[];
    MusicSearch recordingSearch() {
      return (query, {required limit, excludeIds = const {}}) async {
        issued.add(query);
        return <Map<String, dynamic>>[];
      };
    }

    final engine = MusicRecommendationEngine(
      search: recordingSearch(),
      seenStore: MusicSeenStore(),
      session: MusicSessionState(),
    );
    await engine.generateForYou(excludeIds: const {}, count: 12);

    // Favorite artists seed the pool…
    expect(issued, contains('Diljit Dosanjh songs official audio'));
    expect(issued, contains('Arijit Singh songs official audio'));
    // …preferred genres…
    expect(issued, contains('romantic songs official'));
    // …preferred languages…
    expect(issued, contains('Punjabi songs official audio'));
    // …and the favorited song itself.
    expect(issued, contains('Lover Diljit Dosanjh official audio'));

    await store.reset();
  });
}

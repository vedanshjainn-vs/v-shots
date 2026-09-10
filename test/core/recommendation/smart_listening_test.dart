// ═════════════════════════════════════════════════════════════════════════════
// V Shots — SmartListeningService personalization tests (Batch 6: preference-
// driven Daily Mixes, mood mixes and controlled exploration).
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/recommendation/music_recommendation_engine.dart';
import 'package:v_shots/core/recommendation/music_seen_store.dart';
import 'package:v_shots/core/recommendation/music_session_state.dart';
import 'package:v_shots/core/recommendation/signal_store.dart';
import 'package:v_shots/core/recommendation/smart_listening_service.dart';
import 'package:v_shots/core/music/music_candidate_generator.dart'
    show MusicSearch;
import 'package:v_shots/core/storage/local_library.dart';
import 'package:v_shots/core/storage/personalization_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> issued;

  MusicSearch recorder() {
    return (String query,
        {required int limit, Set<String> excludeIds = const {}}) async {
      issued.add(query);
      return List.generate(
        limit.clamp(0, 3),
        (i) => {
          'id': 'q-${issued.length}-$i',
          'title': 'Queue Song $i',
          'artist': 'Queue Artist',
          'artwork': '',
          'duration': 200,
          'isOfficial': true,
        },
      );
    };
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SignalStore.instance.initialize();
    await SignalStore.instance.clear();
    final store = PersonalizationStore.instance;
    await store.initialize();
    await store.reset();
    LocalLibrary.instance.recentlyPlayed.value = [];
    issued = [];

    SmartListeningService.instance.configure(
      engine: MusicRecommendationEngine(
        search: recorder(),
        seenStore: MusicSeenStore(),
        session: MusicSessionState(),
      ),
      repository: null,
      playQueue: (tracks, index) {},
      searchOverride: recorder(),
    );
  });

  test('Daily Mix cold start leads with the favorited song', () async {
    await PersonalizationStore.instance.updatePreferences(
      artists: const ['Diljit Dosanjh'],
      songs: const [
        FavoriteSong(id: 'vid1', title: 'Lover', artist: 'Diljit Dosanjh'),
      ],
    );

    final mix = await SmartListeningService.instance.dailyMix();

    expect(mix, isNotEmpty);
    // The similar-artist pool is seeded from the favorited song.
    expect(
      issued.any(
        (q) => q.contains('Diljit Dosanjh') && q.contains('similar songs'),
      ),
      isTrue,
    );
    // Every track carries its mix identity.
    expect(mix.every((t) => t['smartMix'] == 'Daily Mix 1'), isTrue);
  });

  test('Daily Mix 2 rotates deterministically through favorite artists',
      () async {
    await PersonalizationStore.instance.updatePreferences(
      artists: const ['Arijit Singh', 'Neha Kakkar'],
    );

    // Fixed clock → deterministic rotation (stable within a calendar day).
    final dayA = DateTime(2026, 6, 1); // day 151 → index 1
    final dayB = DateTime(2026, 6, 2); // day 152 → index 0

    final mixA = await SmartListeningService.instance.dailyMix(
      mix: 2,
      now: dayA,
    );
    expect(mixA, isNotEmpty);
    expect(
      issued.any((q) => q.contains('Neha Kakkar')),
      isTrue,
      reason: 'day 151 rotates to artists[1]',
    );

    issued.clear();
    final mixB = await SmartListeningService.instance.dailyMix(
      mix: 2,
      now: dayB,
    );
    expect(mixB, isNotEmpty);
    expect(
      issued.any((q) => q.contains('Arijit Singh')),
      isTrue,
      reason: 'day 152 rotates back to artists[0]',
    );
    expect(mixB.every((t) => t['smartMix'] == 'Daily Mix 2'), isTrue);
  });

  test('listening history still wins over stated taste once it exists',
      () async {
    await PersonalizationStore.instance.updatePreferences(
      artists: const ['Diljit Dosanjh'],
    );
    LocalLibrary.instance.recentlyPlayed.value = [
      {
        'id': 'recent-1',
        'title': 'Recent Song',
        'artist': 'Recent Artist',
        'artwork': '',
        'duration': 200,
      },
    ];

    await SmartListeningService.instance.dailyMix();

    expect(
      issued.any((q) => q.contains('Recent Artist') && q.contains('similar')),
      isTrue,
    );
  });

  test('mood mix respects stated languages', () async {
    await PersonalizationStore.instance.updatePreferences(
      languages: const ['Punjabi'],
    );

    final mix = await SmartListeningService.instance.moodMix('party');

    expect(mix, isNotEmpty);
    expect(issued.any((q) => q.contains('party songs official audio')), isTrue);
    expect(
      issued.any(
        (q) => q.toLowerCase().contains('punjabi songs official audio'),
      ),
      isTrue,
      reason: 'stated language becomes soft context for the mood mix',
    );
  });

  test('Smart Next exploration stays inside stated taste when present',
      () async {
    await PersonalizationStore.instance.updatePreferences(
      languages: const ['Punjabi'],
    );

    await SmartListeningService.instance.nextSongQueue(count: 10);

    expect(
      issued.any((q) => q.contains('Punjabi new discoveries official audio')),
      isTrue,
    );

    // Without preferences the exploration query falls back to region default.
    issued.clear();
    await PersonalizationStore.instance.reset();
    await SmartListeningService.instance.nextSongQueue(count: 10);
    expect(issued.any((q) => q.contains('new discoveries')), isTrue);
    expect(
      issued.any((q) => q.contains('Punjabi new discoveries official audio')),
      isFalse,
    );
  });
}

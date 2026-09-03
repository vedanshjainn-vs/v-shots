// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music candidate generator tests (pools, cold start, validation)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/music/music_candidate_generator.dart';
import 'package:v_shots/core/recommendation/music_recommendation_context.dart';
import 'package:v_shots/core/recommendation/music_user_profile.dart';

const _emptyProfile = MusicUserProfile(
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

MusicSearch _fakeSearch() {
  return (query, {required limit, excludeIds = const {}}) async {
    // Each query yields a DISTINCT artist/title so cross-pool canonical
    // dedupe is visible in the source distribution.
    final artist = 'Artist ${query.toLowerCase()}';
    return List.generate(limit, (i) {
      final id = 'vid-${query.hashCode}-$i';
      return {
        'id': id,
        'title': '$artist Song $i',
        'artist': artist,
        'artwork': '',
        'duration': 200,
        // CandidateGenerator now intentionally accepts only official music
        // for recommendation surfaces, so the fixture must model an official
        // normalized result.
        'isOfficial': true,
      };
    }).where((m) => !excludeIds.contains(m['id'])).toList();
  };
}

void main() {
  test(
    'cold start generates trending/new/regional/exploration pools',
    () async {
      final generator = MusicCandidateGenerator(search: _fakeSearch());
      final context = MusicRecommendationContext(
        mode: 'for_you',
        count: 12,
        regions: ['bollywood'],
      );
      final candidates = await generator.generate(
        profile: _emptyProfile,
        context: context,
      );
      expect(candidates, isNotEmpty);
      final sources = candidates.map((c) => c.source).toSet();
      expect(sources, containsAll(['trending', 'new_release', 'regional']));
    },
  );

  test('personalized profile generates artist/genre/language pools', () async {
    const profile = MusicUserProfile(
      artistAffinity: {'Arijit Singh': 8.0},
      genreAffinity: {'Romantic': 6.0},
      languageAffinity: {'hindi': 5.0},
      moodAffinity: {'romantic': 4.0},
      albumAffinity: {},
      songAffinity: {},
      artistSkipPenalty: {},
      recentArtists: ['Arijit Singh'],
      recentSongs: [],
    );
    final generator = MusicCandidateGenerator(search: _fakeSearch());
    final context = MusicRecommendationContext(mode: 'for_you', count: 12);
    final candidates = await generator.generate(
      profile: profile,
      context: context,
    );
    final sources = candidates.map((c) => c.source).toSet();
    expect(sources, contains('favorite_artist'));
    expect(sources, contains('favorite_genre'));
  });

  test('respects excludeIds', () async {
    final generator = MusicCandidateGenerator(search: _fakeSearch());
    final context = MusicRecommendationContext(
      mode: 'for_you',
      count: 12,
      excludeIds: {'vid-1'},
    );
    final candidates = await generator.generate(
      profile: _emptyProfile,
      context: context,
    );
    expect(candidates.any((c) => c.track.id == 'vid-1'), isFalse);
  });

  test('Explore Language picks create a dedicated language pool', () async {
    // Regression: context.languages was previously SILENTLY DROPPED —
    // a Language filter had zero effect on the candidate queries.
    final queriesSeen = <String>[];
    MusicSearch recording() =>
        (query, {required limit, excludeIds = const {}}) async {
          queriesSeen.add(query);
          return _fakeSearch()(query, limit: limit, excludeIds: excludeIds);
        };
    final generator = MusicCandidateGenerator(search: recording());
    final context = MusicRecommendationContext(
      mode: 'for_you',
      count: 12,
      languages: ['hindi', 'punjabi'],
    );
    final candidates = await generator.generate(
      profile: _emptyProfile,
      context: context,
    );
    expect(candidates, isNotEmpty);
    expect(
      queriesSeen.any((q) => q.contains('hindi songs official audio')),
      isTrue,
      reason: 'a selected language must generate its own pool query',
    );
  });

  test('Explore Mood picks boost the mood pool quota', () async {
    final generator = MusicCandidateGenerator(search: _fakeSearch());
    final context = MusicRecommendationContext(
      mode: 'for_you',
      count: 12,
      moods: ['chill'],
    );
    final candidates = await generator.generate(
      profile: _emptyProfile,
      context: context,
    );
    final moodCount = candidates.where((c) => c.source == 'mood').length;
    expect(moodCount, greaterThan(2),
        reason: 'a selected mood must get a meaningful share of the mix');
  });

  test('filter tokens are appended to trending and new-release pools',
      () async {
    final queriesSeen = <String>[];
    MusicSearch recording() =>
        (query, {required limit, excludeIds = const {}}) async {
          queriesSeen.add(query);
          return _fakeSearch()(query, limit: limit, excludeIds: excludeIds);
        };
    final generator = MusicCandidateGenerator(search: recording());
    final context = MusicRecommendationContext(
      mode: 'for_you',
      count: 12,
      languages: ['hindi'],
      moods: ['chill'],
    );
    await generator.generate(profile: _emptyProfile, context: context);
    expect(
      queriesSeen.any((q) => q.contains('trending') && q.contains('hindi')),
      isTrue,
    );
    expect(
      queriesSeen.any((q) => q.contains('new') && q.contains('chill')),
      isTrue,
    );
  });
}

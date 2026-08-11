// ═════════════════════════════════════════════════════════════════════════
// V Shots — Discover Vibe Filter Isolation Tests
//
// Verifies that each Discover vibe maps to a distinct, category-constrained
// candidate pool and never leaks unrelated categories into the feed (e.g.
// "Heartbroken & Sad" must not surface devotional/party tracks, "Chill &
// LoFi" must not show Bollywood mainstream, "Road Trip" must not become a
// random global catalog, "Punjabi" must stay Punjabi).
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/providers/adapters/youtube/youtube_data_api_client.dart';

void main() {
  group('Discover Vibe Filter Isolation', () {
    late YouTubeDataApiClient client;
    setUp(() => client = YouTubeDataApiClient());
    tearDown(() => client.dispose());

    // Each vibe's real query and the category every returned result must be in.
    const vibeCases = <(String, String, Set<String>)>{
      ('Trending Hits', 'trending hits viral songs official audio', {
        'global',
        'punjabi',
        'bollywood',
      }),
      ('Romantic & Love', 'romantic love songs official audio hindi', {
        'bollywood',
        'indie',
        'global',
      }),
      ('Heartbroken & Sad', 'sad heartbroken emotional songs official audio', {
        'nostalgia',
        'indie',
        'bollywood',
      }),
      ('Hindi Indie', 'hindi indie acoustic songs official audio', {'indie'}),
      ('Punjabi Bangers', 'latest punjabi pop hits official audio', {
        'punjabi',
      }),
      ('Bollywood Hits', 'top bollywood songs official music video', {
        'bollywood',
      }),
      ('Devotional & Bhajans', 'top devotional bhajan aarti songs official audio', {
        'devotional',
      }),
      ('Chill & LoFi', 'chill lofi late night beats official audio', {
        'ambient',
      }),
      ('Workout', 'workout gym motivation hype songs official', {'workout'}),
      ('International Pop', 'billboard top global pop hits official audio', {
        'global',
      }),
      ('Hip-Hop', 'hip hop rap songs official audio', {'workout', 'global'}),
    };

    for (final (label, query, allowedCats) in vibeCases) {
      test('"$label" returns only ${allowedCats.join(',')} content', () async {
        final results = await client.searchMusicVideos(query, maxResults: 15);
        expect(results, isNotEmpty, reason: '"$label" must not be empty');
        for (final r in results) {
          expect(
            allowedCats.contains(r.category),
            isTrue,
            reason:
                '"$label" leaked ${r.category} track: ${r.title} (query "$query")',
          );
        }
      });
    }

    test('Heartbroken & Sad never surfaces devotional/party content', () async {
      const badCategories = {'devotional', 'workout', 'ambient'};
      final results = await client.searchMusicVideos(
        'sad heartbroken emotional songs official audio',
        maxResults: 20,
      );
      for (final r in results) {
        expect(badCategories.contains(r.category), isFalse,
            reason: 'Heartbroken & Sad leaked ${r.category}: ${r.title}');
      }
    });

    test('Punjabi stays strictly Punjabi', () async {
      final results = await client.searchMusicVideos(
        'latest punjabi pop hits official audio',
        maxResults: 20,
      );
      for (final r in results) {
        expect(r.category, 'punjabi',
            reason: 'Punjabi leaked ${r.category}: ${r.title}');
      }
    });
  });
}

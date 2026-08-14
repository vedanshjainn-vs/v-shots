// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — Playlist discovery tests
//
// Verifies the channelSections-driven playlist discovery path and the
// playlist categorization layer WITHOUT hitting the live API:
//   - classifyPlaylistTitle maps known + unknown playlists to categories
//   - channelSections.list -> playlist refs -> real playlists (HTTP mock)
//   - playlists.list?id= resolves playlist metadata
//   - discoverPlaylists gracefully returns empty when nothing is live
// ═════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:v_shots/core/discovery/playlist_content_service.dart';
import 'package:v_shots/core/preferences/user_preferences.dart';
import 'package:v_shots/core/providers/adapters/youtube/youtube_data_api_client.dart';
import 'package:v_shots/core/providers/adapters/youtube/youtube_repository.dart';

void main() {
  group('classifyPlaylistTitle', () {
    test('maps known genre/mood titles to categories', () {
      expect(classifyPlaylistTitle('Trending Now'), 'Trending');
      expect(classifyPlaylistTitle('New Music Friday'), 'New Releases');
      expect(classifyPlaylistTitle('Punjabi Party Hitlist'), 'Punjabi');
      expect(classifyPlaylistTitle('Bollywood Romantic Hits'), 'Hindi');
      expect(classifyPlaylistTitle('Chill & Lo-Fi Beats'), 'Chill');
      expect(classifyPlaylistTitle('Top Devotional Bhajans'), 'Devotional');
    });

    test('keeps unknown playlists under More From YouTube Music', () {
      expect(
        classifyPlaylistTitle('A totally generic list'),
        kUnknownPlaylistCategory,
      );
    });
  });

  group('scored playlist category', () {
    test('scorePlaylist attaches a category', () {
      final svc = PlaylistContentService();
      final scored = svc.scorePlaylist(
        const YouTubePlaylist(
          id: 'PLx',
          title: 'Punjabi Bangers',
          description: '',
          thumbnailUrl: '',
          itemCount: 10,
          channelId: 'c',
        ),
        UserPreferences(country: 'India', languages: ['Punjabi']),
      );
      expect(scored.category, 'Punjabi');
    });
  });

  group('channelSections-driven discovery', () {
    YouTubeRepository repoWithSections() {
      // Mock YouTube Data API:
      //  - channelSections.list returns 1 section referencing PL111
      //  - playlists.list?id=PL111 resolves its metadata
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/channelSections')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'sec1',
                  'snippet': {'type': 'singlePlaylist'},
                  'contentDetails': {
                    'playlists': ['PL111']
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/playlists')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'PL111',
                  'snippet': {
                    'channelId': 'chan',
                    'title': 'Trending Hits',
                    'description': 'Top tracks',
                    'thumbnails': {
                      'high': {'url': 'http://img/PL111'}
                    },
                  },
                  'contentDetails': {'itemCount': 40},
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"items":[]}', 200,
            headers: {'content-type': 'application/json'});
      });
      return YouTubeRepository(
        client: YouTubeDataApiClient(httpClient: mock, apiKey: 'AIzaTEST'),
      );
    }

    test('listChannelSections parses playlist refs from the API', () async {
      final repo = repoWithSections();
      final sections = await repo.listChannelSections(kYouTubeMusicChannelId);
      expect(sections, isNotEmpty);
      expect(sections.first.playlistIds, contains('PL111'));
    });

    test('discoverPlaylists resolves channelSection refs into playlists',
        () async {
      final svc = PlaylistContentService(repository: repoWithSections());
      final found = await svc.discoverPlaylists();
      expect(found, isNotEmpty);
      expect(found.any((p) => p.id == 'PL111'), isTrue);
      expect(found.any((p) => p.title == 'Trending Hits'), isTrue);
    });

    test('discoverPlaylists returns configured playlists when not live',
        () async {
      // Real client with no API key -> live paths skipped, but user-verified
      // configured playlists are still returned (graceful, no crash).
      final svc = PlaylistContentService();
      final found = await svc.discoverPlaylists();
      expect(found, isNotEmpty);
      expect(found.every((p) => p.id.isNotEmpty), isTrue);
    });

    test('discoverPlaylists includes configured playlist ids', () async {
      final svc = PlaylistContentService(repository: repoWithSections());
      final found = await svc.discoverPlaylists();
      // Configured real playlist ids (from the offline/runtime list) appear.
      expect(found.any((p) => p.id == 'PL4fGSI1pDJn4tiNLMZVGGt2Kghgw__2u0'),
          isTrue);
    });
  });
}

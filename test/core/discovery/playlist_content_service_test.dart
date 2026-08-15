// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — Playlist content tests
//
// Verifies the playlist-driven Home pipeline without a live API key:
//   - playlist relevance scoring respects country + language
//   - Hindi/Punjabi user ranks Hindi/Punjabi playlists above unrelated ones
//   - US/English user does not get India/Hindi playlists as top relevance
//   - empty API (no key) yields empty discovery gracefully
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/discovery/playlist_content_service.dart';
import 'package:v_shots/core/preferences/user_preferences.dart';
import 'package:v_shots/core/providers/adapters/youtube/youtube_data_api_client.dart';

YouTubePlaylist playlist(String id, String title) => YouTubePlaylist(
      id: id,
      title: title,
      description: '',
      thumbnailUrl: 'http://img/$id',
      itemCount: 20,
      channelId: 'chan',
    );

void main() {
  final svc = PlaylistContentService();

  group('playlist relevance scoring', () {
    test('India + Hindi ranks Hindi playlist above English', () {
      final prefs = UserPreferences(country: 'India', languages: ['Hindi']);
      final hindi = svc.scorePlaylist(
        playlist('a', 'Top Weekly Videos Hindi'),
        prefs,
      );
      final english = svc.scorePlaylist(
        playlist('b', 'Top 100 Music Videos Global'),
        prefs,
      );
      expect(hindi.relevance, greaterThan(english.relevance));
      expect(hindi.languageScore, greaterThan(0.5));
    });

    test('India + Punjabi ranks Punjabi playlist highly', () {
      final prefs = UserPreferences(country: 'India', languages: ['Punjabi']);
      final punjabi = svc.scorePlaylist(
        playlist('p', 'Punjabi Party Hitlist'),
        prefs,
      );
      expect(punjabi.languageScore, greaterThan(0.5));
      expect(punjabi.relevance, greaterThan(0.4));
    });

    test('US + English user does NOT rank Hindi playlist as top relevance', () {
      final prefs =
          UserPreferences(country: 'United States', languages: ['English']);
      final hindi = svc.scorePlaylist(
        playlist('h', 'Top Weekly Videos Hindi'),
        prefs,
      );
      final global = svc.scorePlaylist(
        playlist('g', 'Top 100 Music Videos Global'),
        prefs,
      );
      expect(global.relevance, greaterThan(hindi.relevance));
    });

    test('discoverPlaylists returns configured playlists when not live',
        () async {
      // No API key -> live paths are skipped, but the user-verified configured
      // playlists are still returned (offline fallback). No crash.
      final found = await svc.discoverPlaylists();
      expect(found, isNotEmpty);
      expect(
        found.every((p) => p.id.isNotEmpty && p.title.isNotEmpty),
        isTrue,
      );
    });
  });
}

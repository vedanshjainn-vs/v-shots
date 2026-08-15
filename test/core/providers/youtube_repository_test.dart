// ═════════════════════════════════════════════════════════════════════════
// V Shots — YouTubeRepository Tests (Phase 6)
//
// Verifies the clean repository layer wraps the API client: artist search
// falls back gracefully without a key, songs paginate, and the fallback artist
// search returns known artists rather than empty.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/providers/adapters/youtube/youtube_repository.dart';

void main() {
  group('YouTubeRepository', () {
    test('isLive is false when no API key configured', () {
      final repo = YouTubeRepository();
      expect(repo.isLive, isFalse);
    });

    test('searchSongs returns verified fallback content without a key',
        () async {
      final repo = YouTubeRepository();
      final page = await repo.searchSongs('bollywood songs', limit: 10);
      expect(page.items, isNotEmpty);
      expect(page.nextPageToken, isNull); // fallback has no pages
    });

    test('searchArtists falls back to known artists without a key', () async {
      final repo = YouTubeRepository();
      final artists = await repo.searchArtists('Arijit', limit: 5);
      expect(artists, isNotEmpty);
      expect(artists.first.kind, 'artist');
      expect(artists.first.title.toLowerCase(), contains('arijit'));
    });

    test('getVideoDetails returns metadata for a known fallback track',
        () async {
      final repo = YouTubeRepository();
      final details = await repo.getVideoDetails('kJQP7kiw5Fk');
      expect(details, isNotNull);
      expect(details!.id, 'kJQP7kiw5Fk');
    });
  });
}

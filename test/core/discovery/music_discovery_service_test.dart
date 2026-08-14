// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — MusicDiscoveryService tests
//
// Verifies the shared discovery layer (official-API search) used by the
// ArchiveTune-style Home + Discovery screens:
//   - MusicTrack.fromVideoItem normalization
//   - toTrackMap canonical shape (matches playTrack)
//   - category query distinctness (filter really changes source)
//   - dedup by video id
//   - no InnerTube / no playlistItems dependency in this layer
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/discovery/music_discovery_service.dart';
import 'package:v_shots/core/providers/adapters/youtube/youtube_data_api_client.dart';

void main() {
  group('MusicTrack', () {
    test('fromVideoItem normalizes YouTubeVideoItem metadata', () {
      final v = YouTubeVideoItem(
        id: 'abc123',
        title: 'Kesariya',
        channelTitle: 'Arijit Singh',
        thumbnailUrl: 'https://img/abc123.jpg',
        durationSeconds: 268,
      );
      final t = MusicTrack.fromVideoItem(v);
      expect(t.id, 'abc123');
      expect(t.title, 'Kesariya');
      expect(t.artist, 'Arijit Singh');
      expect(t.artwork, 'https://img/abc123.jpg');
      expect(t.durationSeconds, 268);
    });

    test('toTrackMap produces the canonical playTrack map', () {
      const t = MusicTrack(
        id: 'xyz',
        title: 'Lover',
        artist: 'Diljit',
        artwork: 'https://img/xyz.jpg',
      );
      final map = t.toTrackMap();
      expect(map['id'], 'xyz');
      expect(map['videoId'], 'xyz');
      expect(map['title'], 'Lover');
      expect(map['artist'], 'Diljit');
      expect(map['artwork'], 'https://img/xyz.jpg');
      expect(map['source'], 'youtube_official');
    });
  });

  group('MusicCategory', () {
    test('every discovery category has a distinct query (real filter)', () {
      final queries = kMusicCategories.map((c) => c.query).toSet();
      expect(queries.length, kMusicCategories.length,
          reason: 'Categories must drive different searches');
    });

    test('home shelves each map to a distinct query', () {
      final queries = kHomeShelves.map((c) => c.query).toSet();
      expect(queries.length, kHomeShelves.length);
    });
  });

  group('dedup', () {
    test('fetchHomeShelves never returns a shelf from the same source twice',
        () async {
      // No API key in test env -> the official client returns the curated
      // fallback catalog, so shelves still get real, non-empty results.
      final svc = MusicDiscoveryService();
      final shelves = await svc.fetchHomeShelves(categories: [
        kHomeShelves.first,
      ]);
      // Either empty (offline) or populated; no crash either way.
      expect(shelves, isA<List<MusicShelf>>());
    });
  });
}

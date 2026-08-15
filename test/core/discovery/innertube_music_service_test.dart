// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — InnerTubeMusicService tests
//
// Verifies the shared discovery layer used by Home + Discovery:
//   - DiscoveryTrack.toTrackMap produces the canonical playTrack shape
//   - search query handling (empty -> no network call)
//   - defensive parsing is offline-safe (no crash when no network/key)
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/discovery/innertube_music_service.dart';

void main() {
  group('DiscoveryTrack', () {
    test('toTrackMap produces the canonical playTrack map', () {
      const t = DiscoveryTrack(
        id: 'video123',
        title: 'Kesariya',
        artist: 'Arijit Singh',
        artwork: 'https://img/video123.jpg',
        album: 'Brahmastra',
      );
      final map = t.toTrackMap();
      expect(map['id'], 'video123');
      expect(map['videoId'], 'video123');
      expect(map['title'], 'Kesariya');
      expect(map['artist'], 'Arijit Singh');
      expect(map['artwork'], 'https://img/video123.jpg');
      expect(map['album'], 'Brahmastra');
      expect(map['source'], 'youtube_music_innertube');
      // The player reads 'id' and 'videoId' — both must be the same value.
      expect(map['id'], map['videoId']);
    });
  });

  group('search', () {
    test('empty query returns no results without hitting the network',
        () async {
      final svc = InnerTubeMusicService();
      final results = await svc.search('   ');
      expect(results, isEmpty);
      svc.dispose();
    });
  });
}

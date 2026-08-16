// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music model round-trip tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/music/music_models.dart';

void main() {
  test('toTrackMap / fromTrackMap round-trip preserves music metadata', () {
    const item = VShotsMusicItem(
      id: 'vid123',
      youtubeVideoId: 'vid123',
      title: 'Kesariya',
      artistName: 'Arijit Singh',
      artworkUrl: 'https://i.ytimg.com/vi/vid123/hqdefault.jpg',
      durationSeconds: 250,
      channelId: 'UC_official',
      channelName: 'T-Series',
      isOfficial: true,
      musicConfidence: 0.9,
    );
    final map = item.toTrackMap();
    expect(map['id'], 'vid123');
    expect(map['title'], 'Kesariya');
    expect(map['artist'], 'Arijit Singh');
    expect(map['isOfficial'], isTrue);
    expect(map['channelId'], 'UC_official');
    expect(map['duration'], 250);

    final rt = VShotsMusicItem.fromTrackMap(map);
    expect(rt.id, 'vid123');
    expect(rt.title, 'Kesariya');
    expect(rt.artistName, 'Arijit Singh');
    expect(rt.isOfficial, isTrue);
  });

  test('unbadged items omit official/channel keys (no fake metadata)', () {
    const item = VShotsMusicItem(id: 'x', title: 'T', artistName: 'A');
    final map = item.toTrackMap();
    expect(map.containsKey('isOfficial'), isFalse);
    expect(map.containsKey('channelId'), isFalse);
  });
}

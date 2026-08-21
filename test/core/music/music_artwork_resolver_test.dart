// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music artwork resolver priority tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/music/music_artwork_resolver.dart';

void main() {
  const resolver = MusicArtworkResolver();

  test('prefers album artwork over music/structured/thumbnail', () {
    expect(
      resolver.resolve(
        albumArtwork: 'album.jpg',
        musicArtwork: 'music.jpg',
        structuredArtwork: 'struct.jpg',
        videoThumbnail: 'thumb.jpg',
      ),
      'album.jpg',
    );
  });

  test('falls through the priority chain', () {
    expect(
      resolver.resolve(musicArtwork: 'music.jpg', videoThumbnail: 'thumb.jpg'),
      'music.jpg',
    );
    expect(resolver.resolve(videoThumbnail: 'thumb.jpg'), 'thumb.jpg');
  });

  test('skips empty strings (never returns an empty url)', () {
    expect(
      resolver.resolve(albumArtwork: '', videoThumbnail: 'thumb.jpg'),
      'thumb.jpg',
    );
  });

  test('returns null when nothing is available (no fabrication)', () {
    expect(resolver.resolve(), isNull);
  });
}

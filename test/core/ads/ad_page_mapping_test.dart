// ═════════════════════════════════════════════════════════════════════════
// V Shots — Discovery Ad Page Mapping Tests (Section 7)
//
// Verifies the page<->song index math used to insert clearly-separated ad
// pages into the vertical Discovery feed WITHOUT breaking the video index
// (currentQueue, auto-advance, skip). Mirrors the helpers in
// for_you_feed_screen.dart.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/ads/ad_config.dart';

// Mirrors for_you_feed_screen.dart's ad-page helpers.
int adCountFor(int songCount) => songCount ~/ AdConfig.discoveryAdEvery;
int pageCount(int songs) => songs + adCountFor(songs);
bool isAdPage(int page) {
  if (page == 0) return false;
  return (page - AdConfig.discoveryAdEvery) % (AdConfig.discoveryAdEvery + 1) ==
      0;
}

int songIndexForPage(int page) =>
    page - (page ~/ (AdConfig.discoveryAdEvery + 1));
int pageForSongIndex(int songIndex) =>
    songIndex + (songIndex ~/ AdConfig.discoveryAdEvery);

void main() {
  group('Discovery ad page mapping (Section 7)', () {
    test('ad pages appear after every N songs and never first', () {
      for (var page = 0; page < 50; page++) {
        if (page == 0) {
          expect(isAdPage(page), isFalse, reason: 'page 0 is never an ad');
        } else {
          final expected = (page - 9) % 10 == 0;
          expect(isAdPage(page), expected, reason: 'page $page');
        }
      }
      expect(isAdPage(9), isTrue);
      expect(isAdPage(19), isTrue);
      expect(isAdPage(29), isTrue);
      expect(isAdPage(8), isFalse);
      expect(isAdPage(10), isFalse);
    });

    test('songIndexForPage skips ad pages correctly', () {
      // page 9 is an ad -> songs 0..8 at pages 0..8, song 9 at page 10
      expect(songIndexForPage(0), 0);
      expect(songIndexForPage(8), 8);
      expect(songIndexForPage(10), 9);
      expect(songIndexForPage(11), 10);
      expect(songIndexForPage(20), 18);
    });

    test('pageForSongIndex round-trips through songIndexForPage', () {
      for (var song = 0; song < 40; song++) {
        final page = pageForSongIndex(song);
        expect(songIndexForPage(page), song);
      }
    });
  });
}

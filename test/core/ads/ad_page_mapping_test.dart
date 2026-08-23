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
      const n = AdConfig.discoveryAdEvery;
      for (var page = 0; page < 50; page++) {
        if (page == 0) {
          expect(isAdPage(page), isFalse, reason: 'page 0 is never an ad');
        } else {
          final expected = (page - n) % (n + 1) == 0;
          expect(isAdPage(page), expected, reason: 'page $page');
        }
      }
      expect(isAdPage(n), isTrue, reason: 'first ad right after $n songs');
      expect(isAdPage(2 * n + 1), isTrue);
      expect(isAdPage(3 * n + 2), isTrue);
      expect(isAdPage(n - 1), isFalse);
      expect(isAdPage(n + 1), isFalse);
    });

    test('songIndexForPage skips ad pages correctly', () {
      const n = AdConfig.discoveryAdEvery;
      // pages 0..n-1 = songs 0..n-1; page n is the ad; song n at page n+1
      expect(songIndexForPage(0), 0);
      expect(songIndexForPage(n - 1), n - 1);
      expect(songIndexForPage(n + 1), n);
      expect(songIndexForPage(n + 2), n + 1);
      expect(songIndexForPage(2 * n + 3), 2 * n + 1);
    });

    test('pageForSongIndex round-trips through songIndexForPage', () {
      for (var song = 0; song < 40; song++) {
        final page = pageForSongIndex(song);
        expect(songIndexForPage(page), song);
      }
    });
  });
}

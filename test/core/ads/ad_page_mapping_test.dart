// ═════════════════════════════════════════════════════════════════════════
// V Shots — Discovery Ad Page Mapping Tests (Section 7)
//
// Verifies the page<->song index math used to insert clearly-separated ad
// pages into the vertical Discovery feed WITHOUT breaking the video index
// (currentQueue, auto-advance, skip). Mirrors the helpers in
// for_you_feed_screen.dart.
//
// Regression coverage for the device crash "RangeError (length): Invalid
// value: Not in inclusive range 0..23: 24" (For You tab): when ads are
// DISABLED the page count must equal the song count (no phantom ad pages),
// and when ads are ENABLED there must be no trailing ad page past the last
// song (both invariants broke deep swipes otherwise).
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/ads/ad_config.dart';

// Mirrors for_you_feed_screen.dart's ad-page helpers.
int adCountFor(int songCount, bool adsEnabled) {
  if (!adsEnabled || songCount <= 0) return 0;
  return (songCount - 1) ~/ AdConfig.discoveryAdEvery;
}

int pageCount(int songs, bool adsEnabled) =>
    songs + adCountFor(songs, adsEnabled);

bool isAdPage(int page, bool adsEnabled) {
  if (!adsEnabled) return false;
  if (page == 0) return false;
  return (page - AdConfig.discoveryAdEvery) % (AdConfig.discoveryAdEvery + 1) ==
      0;
}

int songIndexForPage(int page, bool adsEnabled) {
  if (!adsEnabled) return page;
  final adsBefore = page ~/ (AdConfig.discoveryAdEvery + 1);
  return page - adsBefore;
}

int pageForSongIndex(int songIndex, bool adsEnabled) {
  if (!adsEnabled) return songIndex;
  return songIndex + (songIndex ~/ AdConfig.discoveryAdEvery);
}

void main() {
  group('Discovery ad page mapping (Section 7)', () {
    const n = AdConfig.discoveryAdEvery;

    test('REGRESSION: ads disabled ⇒ zero phantom pages (24-item feed)', () {
      // The device crash: 24 songs + 6 phantom ad pages ⇒ PageView page 24
      // mapped to _items[24] out of range.
      for (final songs in [0, 1, 4, 8, 23, 24, 25, 40, 64]) {
        expect(pageCount(songs, false), songs,
            reason: 'no ad pages when ads are off ($songs songs)');
        expect(adCountFor(songs, false), 0);
      }
    });

    test('REGRESSION: 24 songs, ads on ⇒ last page is a SONG, no trailing ad',
        () {
      final songs = 24;
      final pages = pageCount(songs, true);
      // 5 ads (after songs 4, 8, 12, 16, 20) — NOT after the last song.
      expect(pages, songs + (songs - 1) ~/ n);
      final lastPage = pages - 1;
      expect(isAdPage(lastPage, true), isFalse,
          reason: 'no ad page after the last song');
      expect(songIndexForPage(lastPage, true), songs - 1,
          reason: 'last page shows the last song');
    });

    test('ad pages appear after every N songs and never first', () {
      for (var page = 0; page < 50; page++) {
        if (page == 0) {
          expect(isAdPage(page, true), isFalse,
              reason: 'page 0 is never an ad');
        } else {
          final expected = (page - n) % (n + 1) == 0;
          expect(isAdPage(page, true), expected, reason: 'page $page');
        }
      }
      expect(isAdPage(n, true), isTrue,
          reason: 'first ad right after $n songs');
      expect(isAdPage(2 * n + 1, true), isTrue);
      expect(isAdPage(3 * n + 2, true), isTrue);
      expect(isAdPage(n - 1, true), isFalse);
      expect(isAdPage(n + 1, true), isFalse);
    });

    test('every page in range maps to an ad page or a valid song index', () {
      for (final songs in [0, 1, n - 1, n, n + 1, 24, 25, 40, 100]) {
        final pages = pageCount(songs, true);
        for (var page = 0; page < pages; page++) {
          if (isAdPage(page, true)) continue;
          final song = songIndexForPage(page, true);
          expect(song, inInclusiveRange(0, songs - 1),
              reason:
                  '$songs songs: page $page mapped to song $song OUT OF RANGE');
        }
      }
    });

    test('Continue on the LAST ad page never jumps past the feed end', () {
      for (final songs in [n, n + 1, 24, 40]) {
        final pages = pageCount(songs, true);
        for (var page = 0; page < pages; page++) {
          if (isAdPage(page, true)) {
            expect(page + 1, lessThan(pages),
                reason:
                    'Continue from ad page $page ($songs songs) exceeds end');
          }
        }
      }
    });

    test('songIndexForPage skips ad pages correctly', () {
      // pages 0..n-1 = songs 0..n-1; page n is the ad; song n at page n+1
      expect(songIndexForPage(0, true), 0);
      expect(songIndexForPage(n - 1, true), n - 1);
      expect(songIndexForPage(n + 1, true), n);
      expect(songIndexForPage(n + 2, true), n + 1);
      expect(songIndexForPage(2 * n + 3, true), 2 * n + 1);
    });

    test('pageForSongIndex round-trips through songIndexForPage', () {
      for (var song = 0; song < 40; song++) {
        final page = pageForSongIndex(song, true);
        expect(songIndexForPage(page, true), song);
      }
    });
  });
}

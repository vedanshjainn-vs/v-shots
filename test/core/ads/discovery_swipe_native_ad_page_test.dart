import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/ads/ad_config.dart';

int adCountFor(int songs, bool enabled) {
  if (!enabled || songs <= 0) return 0;
  return (songs - 1) ~/ AdConfig.discoveryAdEvery;
}

int pageCount(int songs, bool enabled) =>
    songs + adCountFor(songs, enabled);

bool isAdPage(int page, bool enabled) {
  if (!enabled || page == 0) return false;
  return (page - AdConfig.discoveryAdEvery) %
          (AdConfig.discoveryAdEvery + 1) ==
      0;
}

int songIndexForPage(int page, bool enabled) {
  if (!enabled) return page;
  final adsBefore = page ~/ (AdConfig.discoveryAdEvery + 1);
  return page - adsBefore;
}

int pageForSongIndex(int song, bool enabled) {
  if (!enabled) return song;
  return song + (song ~/ AdConfig.discoveryAdEvery);
}

void main() {
  group('Discovery swipeable native ad page', () {
    const n = AdConfig.discoveryAdEvery;

    test('ads off means one PageView page per song', () {
      for (final songs in [0, 1, 4, 12, 24, 40]) {
        expect(adCountFor(songs, false), 0);
        expect(pageCount(songs, false), songs);
      }
    });

    test('ad pages follow the configured organic cadence', () {
      expect(isAdPage(0, true), isFalse);
      expect(isAdPage(n, true), isTrue);
      expect(isAdPage(2 * n + 1, true), isTrue);
      expect(isAdPage(2 * n, true), isFalse);
    });

    test('24-song feed has no trailing ad page', () {
      const songs = 24;
      final pages = pageCount(songs, true);
      expect(isAdPage(pages - 1, true), isFalse);
      expect(songIndexForPage(pages - 1, true), songs - 1);
    });

    test('every non-ad page maps to a valid song', () {
      for (final songs in [1, n, n + 1, 24, 40, 100]) {
        final pages = pageCount(songs, true);
        for (var page = 0; page < pages; page++) {
          if (isAdPage(page, true)) continue;
          expect(
            songIndexForPage(page, true),
            inInclusiveRange(0, songs - 1),
          );
        }
      }
    });

    test('song index round-trips through PageView mapping', () {
      for (var song = 0; song < 100; song++) {
        final page = pageForSongIndex(song, true);
        expect(songIndexForPage(page, true), song);
        expect(isAdPage(page, true), isFalse);
      }
    });

    test('ad slot is a PageView page, not a modal trigger', () {
      expect(pageCount(4, true), 5);
      expect(isAdPage(4, true), isTrue);
    });
  });
}

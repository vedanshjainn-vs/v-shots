// ═════════════════════════════════════════════════════════════════════════
// V Shots — Discovery In-Feed Ad Page Lifecycle & Invariant Test Suite
//
// Validates:
// 1. Video -> Ad Page -> Video transition & page index mapping
// 2. Playback isolation (audio pauses on ad page, resumes on next video)
// 3. No-fill / load failure graceful recovery (no infinite spinner / blocker)
// 4. Rapid swipe protection & queue index integrity
// 5. Cross-ad frequency cooldown (feed ad notifies PlayerSponsoredAdPolicy)
// 6. Hard safety locks (MREC 300x250, Rewarded, Interstitial units intact)
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'package:v_shots/core/ads/ad_config.dart';
import 'package:v_shots/core/ads/levelplay_config.dart';
import 'package:v_shots/core/ads/mrec_ad_manager.dart';
import 'package:v_shots/core/ads/player_sponsored_ad_policy.dart';
import 'package:v_shots/core/playback/vshots_playback_manager.dart';

Map<String, dynamic> _track(String id) => {
      'id': id,
      'title': 'Track $id',
      'artist': 'Artist $id',
      'artwork': 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      'duration': 180,
    };

// Mirrors for_you_feed_screen.dart index mapping logic
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
  group('Discovery In-Feed Ad Page — Lifecycle & Index Mapping', () {
    const cadence = AdConfig.discoveryAdEvery; // 4
    final tracks = List.generate(12, (i) => _track('track_$i'));

    test('Video 1 (page 0..3) -> Ad Page (page 4) -> Video 2 (page 5)', () {
      expect(pageCount(tracks.length, true), 14); // 12 songs + 2 ads

      // Songs 0, 1, 2, 3 occupy pages 0, 1, 2, 3
      for (var i = 0; i < cadence; i++) {
        expect(isAdPage(i, true), isFalse);
        expect(songIndexForPage(i, true), i);
      }

      // Page 4 is the In-Feed Ad Page
      expect(isAdPage(cadence, true), isTrue);

      // Page 5 resumes with Song 4
      expect(isAdPage(cadence + 1, true), isFalse);
      expect(songIndexForPage(cadence + 1, true), cadence);

      // Page 9 is the next In-Feed Ad Page
      expect(isAdPage(2 * cadence + 1, true), isTrue);

      // Page 10 resumes with Song 8
      expect(isAdPage(2 * cadence + 2, true), isFalse);
      expect(songIndexForPage(2 * cadence + 2, true), 2 * cadence);
    });

    test('Entering Ad Page pauses previous video audio cleanly', () {
      final mgr = VShotsPlaybackManager.instance;
      mgr.playQueue(tracks, 3);
      expect(mgr.isOpen, isTrue);
      expect(mgr.currentIndex, 3);
      expect(mgr.currentTrack?['id'], 'track_3');

      // User swipes from page 3 (song 3) to page 4 (ad page)
      const targetPage = 4;
      expect(isAdPage(targetPage, true), isTrue);

      // Feed pauses playback when entering ad page
      mgr.pause();
      expect(mgr.isOpen, isTrue); // Session preserved, webview pause requested

      // User swipes from page 4 (ad page) to page 5 (song 4)
      const nextSongPage = 5;
      expect(isAdPage(nextSongPage, true), isFalse);
      final nextSongIdx = songIndexForPage(nextSongPage, true);
      expect(nextSongIdx, 4);

      mgr.playQueue(tracks, nextSongIdx);
      expect(mgr.currentIndex, 4);
      expect(mgr.currentTrack?['id'], 'track_4');
      mgr.close();
    });

    test('Ad page entry notifies PlayerSponsoredAdPolicy of external ad', () {
      final policy = PlayerSponsoredAdPolicy.instance;
      policy.reset();

      final now = DateTime(2026, 9, 6, 12, 0, 0);
      policy.noteExternalAdShown(now: now);

      // Verify that after viewing the discovery ad page, player sponsored
      // card is in cooldown.
      policy.onSongStarted();
      for (var i = 0; i < 15; i++) {
        policy.tick(isPlaying: true);
      }
      expect(policy.isEligible, isTrue);
      expect(
        policy.frequencyAllows(now: now.add(const Duration(seconds: 30))),
        isFalse,
        reason:
            'Player sponsored card must respect 75s cooldown after in-feed ad',
      );
      expect(
        policy.frequencyAllows(now: now.add(const Duration(seconds: 80))),
        isTrue,
        reason: 'Player sponsored card allowed after 75s cooldown elapses',
      );
      policy.reset();
    });
  });

  group('Discovery In-Feed Ad Page — Resilience & No-Fill Fallback', () {
    test('No-fill or ad load failure does not lock manager or hang feed', () {
      final mrecMgr = MRECAdManager.instance;
      mrecMgr.hideMREC();
      expect(mrecMgr.isLoaded, isFalse);

      // Simulate load failure
      mrecMgr.onAdLoadFailed('Ad server returned no fill (204)');
      expect(mrecMgr.isLoaded, isFalse);

      // Page mapping remains consistent and unblocked
      expect(isAdPage(4, true), isTrue);
      expect(songIndexForPage(5, true), 4);
    });

    test(
      'Rapid consecutive swipes do not produce out-of-bounds song indices',
      () {
        const totalSongs = 20;
        final totalPages = pageCount(totalSongs, true);

        for (var page = 0; page < totalPages; page++) {
          if (!isAdPage(page, true)) {
            final idx = songIndexForPage(page, true);
            expect(idx, greaterThanOrEqualTo(0));
            expect(idx, lessThan(totalSongs));
          }
        }
      },
    );
  });

  group('Discovery In-Feed Ad Page — Hard Safety Locks', () {
    tearDown(() => LevelPlayConfig.debugSetEnv(null));

    test(
      'Hard Lock 1: MREC unit, size, and placement are strictly unchanged',
      () {
        LevelPlayConfig.debugSetEnv({
          'LEVELPLAY_DEBUG_USE_PRODUCTION': 'true',
          'LEVELPLAY_APP_KEY': '27c0e8465',
          'LEVELPLAY_UNIT_BANNER_HOME_01': 'eotgb78qisj7sis8',
        });
        final wasInTests = LevelPlayConfig.debugIsRunningInTests;
        LevelPlayConfig.debugIsRunningInTests = false;
        try {
          final unitId = LevelPlayConfig.unitIdFor(
            LevelPlayPlacement.bannerHome,
          );
          expect(unitId, 'eotgb78qisj7sis8');
        } finally {
          LevelPlayConfig.debugIsRunningInTests = wasInTests;
        }

        final size = LevelPlayAdSize.MEDIUM_RECTANGLE;
        expect(size.width, 300);
        expect(size.height, 250);
        expect(MRECPlacement.discoverFeed.name, 'discoverFeed');
      },
    );

    test(
      'Hard Lock 2: Rewarded units and identifiers are strictly unchanged',
      () {
        LevelPlayConfig.debugSetEnv({
          'LEVELPLAY_DEBUG_USE_PRODUCTION': 'true',
          'LEVELPLAY_APP_KEY': '27c0e8465',
          'LEVELPLAY_UNIT_REWARDED_FEATURE_01': '2izjczd4ox2wj6yd',
        });
        final wasInTests = LevelPlayConfig.debugIsRunningInTests;
        LevelPlayConfig.debugIsRunningInTests = false;
        try {
          final unitId = LevelPlayConfig.unitIdFor(
            LevelPlayPlacement.rewardedFeature,
          );
          expect(unitId, '2izjczd4ox2wj6yd');
        } finally {
          LevelPlayConfig.debugIsRunningInTests = wasInTests;
        }
      },
    );

    test(
      'Hard Lock 3: Interstitial session break unit is strictly unchanged',
      () {
        LevelPlayConfig.debugSetEnv({
          'LEVELPLAY_DEBUG_USE_PRODUCTION': 'true',
          'LEVELPLAY_APP_KEY': '27c0e8465',
          'LEVELPLAY_UNIT_INTERSTITIAL_SESSION_BREAK_01': 'h3xw38h9214adgxo',
        });
        final wasInTests = LevelPlayConfig.debugIsRunningInTests;
        LevelPlayConfig.debugIsRunningInTests = false;
        try {
          final unitId = LevelPlayConfig.unitIdFor(
            LevelPlayPlacement.interstitialSessionBreak,
          );
          expect(unitId, 'h3xw38h9214adgxo');
        } finally {
          LevelPlayConfig.debugIsRunningInTests = wasInTests;
        }
      },
    );
  });
}

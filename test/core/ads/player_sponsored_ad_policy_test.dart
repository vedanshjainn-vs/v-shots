// ═════════════════════════════════════════════════════════════════════════
// V Shots — Player Sponsored Ad Policy Tests
//
// Covers the full decision surface of the premium player sponsored card:
//   • eligibility window (10–15 s randomized, listening-time only)
//   • preload lead (no request before it; one request per song)
//   • per-song reset + no-refresh latch (never force-refresh)
//   • frequency rules (75 s interval, 3 song starts, session cap 6)
//   • external ad (feed ad page) coordination
//   • placement-manager variant fitness + no-immediate-repeat
// ═════════════════════════════════════════════════════════════════════════

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/ads/player_sponsored_ad_policy.dart';

void main() {
  group('PlayerSponsoredAdPolicy — eligibility', () {
    test('threshold always rolls within the 10–15 s window', () {
      for (var seed = 0; seed < 200; seed++) {
        final p = PlayerSponsoredAdPolicy(random: Random(seed));
        expect(
          p.threshold,
          allOf(
            greaterThanOrEqualTo(const Duration(seconds: 10)),
            lessThanOrEqualTo(const Duration(seconds: 15)),
          ),
        );
      }
    });

    test('never eligible before 10 s of listening; eligible by 15 s', () {
      final p = PlayerSponsoredAdPolicy(
        random: Random(1),
        minEligibleAfter: const Duration(seconds: 10),
        maxEligibleAfter: const Duration(seconds: 10), // pin threshold at 10
      );
      p.onSongStarted();
      for (var i = 0; i < 9; i++) {
        p.tick(isPlaying: true);
      }
      expect(p.isEligible, isFalse,
          reason: '9 s of listening must never qualify');
      p.tick(isPlaying: true);
      expect(p.isEligible, isTrue);
    });

    test('pausing freezes the accumulator (only listening time counts)', () {
      final p = PlayerSponsoredAdPolicy(
        random: Random(1),
        minEligibleAfter: const Duration(seconds: 10),
        maxEligibleAfter: const Duration(seconds: 10),
      );
      p.onSongStarted();
      for (var i = 0; i < 20; i++) {
        p.tick(isPlaying: false); // paused the whole time
      }
      expect(p.listened, Duration.zero);
      expect(p.isEligible, isFalse);
      expect(p.shouldPreload, isFalse,
          reason: 'no request while the user never actually listened');
    });

    test('mayReveal is false until eligible, then true (fresh session)', () {
      final p = PlayerSponsoredAdPolicy(
        random: Random(2),
        minEligibleAfter: const Duration(seconds: 12),
        maxEligibleAfter: const Duration(seconds: 12),
      );
      p.onSongStarted();
      for (var i = 0; i < 11; i++) {
        p.tick(isPlaying: true);
      }
      expect(p.mayReveal, isFalse);
      p.tick(isPlaying: true);
      expect(p.mayReveal, isTrue);
    });
  });

  group('PlayerSponsoredAdPolicy — preload lead', () {
    test('shouldPreload fires ~2.5 s before the threshold, once per song', () {
      final p = PlayerSponsoredAdPolicy(
        random: Random(3),
        preloadLead: const Duration(milliseconds: 2500),
        minEligibleAfter: const Duration(seconds: 12),
        maxEligibleAfter: const Duration(seconds: 12),
      );
      p.onSongStarted();
      for (var i = 0; i < 9; i++) {
        p.tick(isPlaying: true); // 9 s
      }
      expect(p.shouldPreload, isFalse);
      p.tick(isPlaying: true); // 10 s → 12 − 2.5 = 9.5 crossed at 10 s
      expect(p.shouldPreload, isTrue);
      p.markPreloaded();
      expect(p.shouldPreload, isFalse,
          reason: 'exactly one ad request per song mount');
    });
  });

  group('PlayerSponsoredAdPolicy — per-song reset & latch', () {
    test('onSongStarted resets the accumulator and re-rolls the threshold', () {
      final p = PlayerSponsoredAdPolicy(random: Random(4));
      p.onSongStarted();
      for (var i = 0; i < 8; i++) {
        p.tick(isPlaying: true);
      }
      expect(p.listened, const Duration(seconds: 8));
      p.onSongStarted();
      expect(p.listened, Duration.zero);
      expect(p.isEligible, isFalse);
    });

    test('reveal latches for the song — no refresh loop, ever', () {
      final p = PlayerSponsoredAdPolicy(
        random: Random(5),
        minEligibleAfter: const Duration(seconds: 10),
        maxEligibleAfter: const Duration(seconds: 10),
      );
      p.onSongStarted();
      for (var i = 0; i < 10; i++) {
        p.tick(isPlaying: true);
      }
      expect(p.mayReveal, isTrue);
      p.reveal();
      expect(p.mayReveal, isFalse);
      expect(p.revealsThisSession, 1);
      // Long listening: ticks keep coming but nothing changes.
      for (var i = 0; i < 600; i++) {
        p.tick(isPlaying: true);
      }
      expect(p.mayReveal, isFalse,
          reason: 'NEVER force-refresh every 10–15 s — one creative/song');
      expect(p.revealsThisSession, 1);
    });
  });

  group('PlayerSponsoredAdPolicy — frequency rules', () {
    test('no ad on consecutive songs — needs 3 song starts between reveals',
        () {
      final p = PlayerSponsoredAdPolicy(
        random: Random(6),
        minEligibleAfter: const Duration(seconds: 10),
        maxEligibleAfter: const Duration(seconds: 10),
        minRevealInterval: Duration.zero,
      );
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      p.onSongStarted();
      for (var i = 0; i < 10; i++) {
        p.tick(isPlaying: true);
      }
      p.reveal(now: t0);

      // Song 2: eligible in-listening terms but blocked by song spacing.
      p.onSongStarted();
      for (var i = 0; i < 12; i++) {
        p.tick(isPlaying: true);
      }
      expect(p.isEligible, isTrue);
      expect(p.mayReveal, isFalse, reason: 'song immediately after reveal');

      // Song 3: still blocked (only 1 ad-free song so far).
      p.onSongStarted();
      for (var i = 0; i < 12; i++) {
        p.tick(isPlaying: true);
      }
      expect(p.mayReveal, isFalse);

      // Song 4: two ad-free songs have passed → allowed (interval is 0).
      p.onSongStarted();
      for (var i = 0; i < 12; i++) {
        p.tick(isPlaying: true);
      }
      expect(p.mayReveal, isTrue);
    });

    test('minimum 75 s wall-clock between reveals', () {
      final p = PlayerSponsoredAdPolicy(
        random: Random(7),
        minEligibleAfter: const Duration(seconds: 10),
        maxEligibleAfter: const Duration(seconds: 10),
        minSongsBetweenReveals: 1,
      );
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      p.onSongStarted();
      for (var i = 0; i < 10; i++) {
        p.tick(isPlaying: true);
      }
      p.reveal(now: t0);

      p.onSongStarted(); // satisfies song spacing immediately
      for (var i = 0; i < 10; i++) {
        p.tick(isPlaying: true);
      }
      expect(
        p.frequencyAllows(now: t0.add(const Duration(seconds: 60))),
        isFalse,
        reason: 'inside the 75 s cooldown',
      );
      expect(
        p.frequencyAllows(now: t0.add(const Duration(seconds: 76))),
        isTrue,
      );
    });

    test('hard session cap of 6 reveals', () {
      final p = PlayerSponsoredAdPolicy(
        random: Random(8),
        minEligibleAfter: const Duration(seconds: 10),
        maxEligibleAfter: const Duration(seconds: 10),
        minRevealInterval: Duration.zero,
        minSongsBetweenReveals: 1,
        maxRevealsPerSession: 6,
      );
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      for (var song = 0; song < 6; song++) {
        p.onSongStarted();
        for (var i = 0; i < 10; i++) {
          p.tick(isPlaying: true);
        }
        expect(p.mayReveal, isTrue, reason: 'reveal $song should be allowed');
        p.reveal(now: now);
        now = now.add(const Duration(minutes: 10));
      }
      // 7th song: listening qualifies, everything else qualifies — cap hits.
      p.onSongStarted();
      for (var i = 0; i < 10; i++) {
        p.tick(isPlaying: true);
      }
      expect(p.isEligible, isTrue);
      expect(p.frequencyAllows(now: now), isFalse,
          reason: 'session cap reached');
      expect(p.mayReveal, isFalse);
    });

    test('feed ad page keeps the sponsored card 75 s away', () {
      final p = PlayerSponsoredAdPolicy(
        random: Random(9),
        minEligibleAfter: const Duration(seconds: 10),
        maxEligibleAfter: const Duration(seconds: 10),
      );
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      p.noteExternalAdShown(now: t0);
      p.onSongStarted();
      for (var i = 0; i < 10; i++) {
        p.tick(isPlaying: true);
      }
      expect(p.isEligible, isTrue);
      expect(
          p.frequencyAllows(now: t0.add(const Duration(seconds: 30))), isFalse,
          reason: 'too soon after the in-feed ad page');
      expect(
          p.frequencyAllows(now: t0.add(const Duration(seconds: 80))), isTrue);
    });

    test('reset clears all state (test isolation)', () {
      final p = PlayerSponsoredAdPolicy(random: Random(10));
      p.onSongStarted();
      for (var i = 0; i < 12; i++) {
        p.tick(isPlaying: true);
      }
      p.reveal();
      p.noteExternalAdShown();
      p.reset();
      expect(p.revealsThisSession, 0);
      expect(p.listened, Duration.zero);
      expect(p.frequencyAllows(), isTrue);
      expect(p.mayReveal, isFalse, reason: 'not eligible until listening');
    });
  });

  group('PlayerSponsoredPlacementManager', () {
    test('variant fitness by available gap and cover side', () {
      final m = PlayerSponsoredPlacementManager(random: Random(11));
      // Huge gap: all fit; with repeat-avoidance the picks vary.
      final seen = <PlayerSponsoredVariant>{};
      for (var i = 0; i < 60; i++) {
        seen.add(m.choose(availableGap: 200, coverSide: 300));
      }
      expect(seen, containsAll(PlayerSponsoredVariant.values));

      // Medium gap: glass + corner only (compact needs 96).
      final m2 = PlayerSponsoredPlacementManager(random: Random(12));
      for (var i = 0; i < 40; i++) {
        final v = m2.choose(availableGap: 60, coverSide: 300);
        expect(v, isNot(PlayerSponsoredVariant.compactRow));
      }

      // Tiny gap: only the corner creative (it overlaps the artwork edge).
      final m3 = PlayerSponsoredPlacementManager(random: Random(13));
      for (var i = 0; i < 40; i++) {
        expect(
          m3.choose(availableGap: 12, coverSide: 300),
          PlayerSponsoredVariant.cornerCreative,
        );
      }

      // Nothing fits at all → corner creative fallback (never crashes,
      // never returns null).
      final m4 = PlayerSponsoredPlacementManager(random: Random(14));
      expect(
        m4.choose(availableGap: -20, coverSide: 60),
        PlayerSponsoredVariant.cornerCreative,
      );
    });

    test('never the same variant twice in a row when alternatives exist', () {
      final m = PlayerSponsoredPlacementManager(random: Random(15));
      var last = m.choose(availableGap: 200, coverSide: 300);
      for (var i = 0; i < 100; i++) {
        final v = m.choose(availableGap: 200, coverSide: 300);
        expect(v, isNot(last),
            reason: 'back-to-back repeats are avoided for variety');
        last = v;
      }
    });

    test('exactly one variant is ever returned per call', () {
      final m = PlayerSponsoredPlacementManager(random: Random(16));
      for (var i = 0; i < 50; i++) {
        expect(
          m.choose(availableGap: 150, coverSide: 280),
          isA<PlayerSponsoredVariant>(),
        );
      }
    });
  });
}

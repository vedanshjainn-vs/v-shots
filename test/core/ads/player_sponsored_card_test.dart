// ═════════════════════════════════════════════════════════════════════════
// V Shots — Player Sponsored Card Widget Tests
//
// The SDK-bound paths (ad creation/reveal) require a live LevelPlay
// session and are covered on-device; here we verify the testable
// invariants that protect the player experience:
//   • zero footprint while no ad exists (nothing rendered, ever)
//   • the 1 Hz heartbeat only accumulates while THIS song is playing
//   • clean lifecycle: timer cancelled on dispose (no leaks), full reset
//     on song change
//   • no ad UI is ever mounted when the ad system is not configured
//     (fail-safe: the normal premium player UI simply remains)
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'package:v_shots/core/ads/player_sponsored_ad_policy.dart';
import 'package:v_shots/core/ads/player_sponsored_card.dart';

/// Records what the card asks the policy to do.
class _SpyPolicy extends PlayerSponsoredAdPolicy {
  int songStarts = 0;
  int ticks = 0;
  final List<bool> playingSamples = [];

  @override
  void onSongStarted() {
    songStarts++;
    super.onSongStarted();
  }

  @override
  void tick({required bool isPlaying}) {
    ticks++;
    playingSamples.add(isPlaying);
    super.tick(isPlaying: isPlaying);
  }
}

Widget _host(String trackId, _SpyPolicy policy) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: PlayerSponsoredCard(
              trackId: trackId,
              coverSide: 280,
              policy: policy,
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('PlayerSponsoredCard', () {
    testWidgets('renders nothing while unconfigured — no ad UI at all', (
      tester,
    ) async {
      final spy = _SpyPolicy();
      await tester.pumpWidget(_host('track-1', spy));

      // Let plenty of "listening" time pass — with no session track and
      // the ad system unconfigured, NOTHING may appear.
      await tester.pump(const Duration(seconds: 30));

      expect(find.byType(PlayerSponsoredCard), findsOneWidget);
      expect(find.byType(LevelPlayNativeAdView), findsNothing);
      expect(find.text('Ad · Sponsored'), findsNothing);

      // The heartbeat ran and correctly observed "not this song playing".
      expect(spy.ticks, greaterThan(0));
      expect(spy.playingSamples, isNotEmpty);
      expect(spy.playingSamples.every((p) => p == false), isTrue,
          reason: 'no session track exists in the test env → fail closed');

      // Eligibility therefore never accumulates.
      expect(spy.listened, Duration.zero);
    });

    testWidgets('cancels its heartbeat on dispose — no timer leaks', (
      tester,
    ) async {
      final spy = _SpyPolicy();
      await tester.pumpWidget(_host('track-1', spy));
      await tester.pump(const Duration(seconds: 5));
      final ticksAtUnmount = spy.ticks;

      // Unmount (the user swiped to another card).
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Time keeps passing, but the disposed card must not tick anymore.
      await tester.pump(const Duration(seconds: 10));
      expect(spy.ticks, ticksAtUnmount,
          reason: 'timer must be cancelled in dispose()');
    });

    testWidgets('resets fully when recycled for a different song', (
      tester,
    ) async {
      final spy = _SpyPolicy();
      await tester.pumpWidget(_host('track-1', spy));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(_host('track-2', spy));
      await tester.pump(const Duration(seconds: 2));

      expect(spy.songStarts, 2,
          reason: 'a new song must restart the eligibility window');
      expect(find.byType(LevelPlayNativeAdView), findsNothing);
    });

    testWidgets('survives layout in tight and tall viewports', (tester) async {
      final spy = _SpyPolicy();
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host('track-1', spy));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });
}

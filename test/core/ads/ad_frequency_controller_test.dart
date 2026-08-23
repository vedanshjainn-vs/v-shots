// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Frequency Controller Tests
//
// Cooldown, session cap and minimum-dwell rules for interrupting ads.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/ads/ad_frequency_controller.dart';

void main() {
  group('AdFrequencyController', () {
    test('no interstitial during the minimum foreground dwell (no launch ads)',
        () {
      final c = AdFrequencyController(); // appStartedAt = now
      expect(c.canShow(), isFalse,
          reason: 'a fresh app must never show an interstitial immediately');
    });

    test('cooldown blocks, then allows after minInterval', () {
      final start = DateTime(2026, 8, 23, 10, 0, 0);
      final c = AdFrequencyController(appStartedAt: start);
      final t0 = start.add(const Duration(minutes: 5)); // dwell satisfied

      expect(c.canShow(now: t0), isTrue);

      c.recordShown(now: t0);
      expect(c.canShow(now: t0), isFalse, reason: 'just shown — cooldown');
      expect(c.canShow(now: t0.add(const Duration(seconds: 179))), isFalse);
      expect(c.canShow(now: t0.add(const Duration(seconds: 181))), isTrue,
          reason: 'cooldown (180 s) has elapsed');
    });

    test('session cap is enforced even when cooldowns pass', () {
      final start = DateTime(2026, 8, 23, 10);
      final c = AdFrequencyController(
        appStartedAt: start,
        minInterval: Duration.zero,
        maxPerSession: 2,
        minDwell: Duration.zero,
      );
      final t = start;
      expect(c.canShow(now: t), isTrue);
      c.recordShown(now: t);
      expect(c.canShow(now: t), isTrue, reason: 'zero interval — 2nd allowed');
      c.recordShown(now: t);
      expect(c.canShow(now: t.add(const Duration(hours: 1))), isFalse,
          reason: 'session cap (2) reached');
    });

    test('shownThisSession counts only recorded shows', () {
      final c = AdFrequencyController(appStartedAt: DateTime(2026, 8, 23, 9));
      expect(c.shownThisSession, 0);
      c.recordShown(now: DateTime(2026, 8, 23, 10));
      c.recordShown(now: DateTime(2026, 8, 23, 11));
      expect(c.shownThisSession, 2);
    });

    test('reset clears the budget', () {
      final start = DateTime(2026, 8, 23, 10);
      final c = AdFrequencyController(appStartedAt: start);
      final t = start.add(const Duration(minutes: 10));
      c.recordShown(now: t);
      expect(c.canShow(now: t), isFalse);
      c.reset();
      expect(c.canShow(now: t), isTrue);
    });
  });
}

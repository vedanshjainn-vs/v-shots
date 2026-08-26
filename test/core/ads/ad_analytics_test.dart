// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Analytics Tests
//
// Centralized event capture: recording, vocabulary, bounded session list,
// pluggable sink.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/ads/ad_analytics.dart';

void main() {
  group('AdAnalytics', () {
    setUp(() {
      AdAnalytics.sink = null;
      AdAnalytics.clear();
    });

    test('records events with kind/placement/detail', () {
      AdAnalytics.log('ad_request', placement: 'home');
      AdAnalytics.log('ad_loaded', placement: 'home');
      AdAnalytics.log('ad_load_failed',
          placement: 'search', detail: 'simulated');

      expect(AdAnalytics.session.length, 3);
      expect(AdAnalytics.session.first.kind, 'ad_request');
      expect(AdAnalytics.session.last.detail, 'simulated');
      expect(AdAnalytics.countOf('ad_loaded'), 1);
    });

    test('spec vocabulary is available (no data loss by design)', () {
      const kinds = [
        'ad_request',
        'ad_loaded',
        'ad_load_failed',
        'ad_impression',
        'ad_closed',
        'rewarded_started',
        'rewarded_completed',
        'interstitial_shown',
        'native_rendered',
      ];
      for (final k in kinds) {
        AdAnalytics.log(k);
      }
      expect(AdAnalytics.session.length, kinds.length);
      for (final k in kinds) {
        expect(AdAnalytics.countOf(k), 1);
      }
    });

    test('session list is bounded (oldest dropped)', () {
      for (var i = 0; i < 505; i++) {
        AdAnalytics.log('ad_request', detail: 'i=$i');
      }
      expect(AdAnalytics.session.length, 500);
      expect(AdAnalytics.session.first.detail, 'i=5');
      expect(AdAnalytics.session.last.detail, 'i=504');
    });

    test('pluggable sink receives every event and sink errors are safe', () {
      final seen = <AdEvent>[];
      AdAnalytics.sink = (e) {
        seen.add(e);
        throw StateError('boom'); // must never propagate
      };
      expect(() => AdAnalytics.log('ad_impression'), returnsNormally);
      expect(seen, hasLength(1));
      expect(seen.single.kind, 'ad_impression');
    });

    test('clear empties the session', () {
      AdAnalytics.log('ad_request');
      AdAnalytics.clear();
      expect(AdAnalytics.session, isEmpty);
    });
  });
}

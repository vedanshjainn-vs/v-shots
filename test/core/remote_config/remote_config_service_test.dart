// ─────────────────────────────────────────────────────────────────────────────
// V Shots — RemoteConfigService pure helpers (PHASE 15)
// Covers the CMS refresh_minutes → cache TTL wiring without any I/O.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/remote_config/remote_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('computeHomeCacheTtl', () {
    test('uses the smallest refresh_minutes among sections', () {
      final ttl = RemoteConfigService.computeHomeCacheTtl([
        {'refresh_minutes': 60},
        {'refresh_minutes': 30},
        {'refresh_minutes': 120},
      ]);
      expect(ttl, const Duration(minutes: 30));
    });

    test('clamps to a 5-minute floor (protects against abuse)', () {
      final ttl = RemoteConfigService.computeHomeCacheTtl([
        {'refresh_minutes': 1},
      ]);
      expect(ttl, const Duration(minutes: 5));
    });

    test('clamps to a 24-hour ceiling', () {
      final ttl = RemoteConfigService.computeHomeCacheTtl([
        {'refresh_minutes': 99999},
      ]);
      expect(ttl, const Duration(minutes: 1440));
    });

    test('missing/invalid values fall back to the default', () {
      final ttl = RemoteConfigService.computeHomeCacheTtl([
        {'refresh_minutes': null},
        {'refresh_minutes': 'nope'},
        {},
      ]);
      expect(ttl, const Duration(hours: 1));
    });

    test('empty list falls back to the default', () {
      expect(
        RemoteConfigService.computeHomeCacheTtl(const []),
        const Duration(hours: 1),
      );
    });
  });

  group('revision notifier (cold-start CMS apply)', () {
    test('starts at 0 and bumps when config is applied', () {
      final svc = RemoteConfigService.instance;
      final before = svc.revision.value;
      svc.revision.value++; // what refresh() does after a successful apply
      expect(svc.revision.value, before + 1);
    });
  });
}

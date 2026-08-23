// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad-Free Manager Tests
//
// Temporary rewarded passes + the future premium hook.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/ads/ad_free_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdFreeManager', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to NOT ad-free', () async {
      await AdFreeManager.instance.init();
      expect(AdFreeManager.instance.isAdFree, isFalse);
      expect(AdFreeManager.instance.remaining, isNull);
    });

    test('temporary rewarded pass makes the user ad-free', () async {
      await AdFreeManager.instance.init();
      await AdFreeManager.instance
          .grantTemporaryPass(duration: const Duration(minutes: 60));
      expect(AdFreeManager.instance.isAdFree, isTrue);
      final remaining = AdFreeManager.instance.remaining;
      expect(remaining, isNotNull);
      expect(remaining!.inMinutes, greaterThanOrEqualTo(59));
    });

    test('expired pass is not ad-free', () {
      AdFreeManager.instance.debugSet(
        adFreeUntil: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(AdFreeManager.instance.isAdFree, isFalse);
    });

    test('premium flag (future IAP hook) is ad-free; revocable', () async {
      await AdFreeManager.instance.init();
      await AdFreeManager.instance.setPremiumAdFree(true);
      expect(AdFreeManager.instance.isAdFree, isTrue);
      await AdFreeManager.instance.setPremiumAdFree(false);
      expect(AdFreeManager.instance.isAdFree, isFalse);
    });

    test('init is idempotent and survives repeated calls', () async {
      await AdFreeManager.instance.init();
      await AdFreeManager.instance.init();
      expect(AdFreeManager.instance.isAdFree, isFalse);
    });
  });
}

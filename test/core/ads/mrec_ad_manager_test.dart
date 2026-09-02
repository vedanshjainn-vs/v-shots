import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/ads/mrec_ad_manager.dart';

void main() {
  final manager = MRECAdManager.instance;

  setUp(manager.resetForTesting);

  test('allows one MREC load at a time (maxVisible = 1)', () {
    final first = manager.loadMREC(MRECPlacement.home);
    expect(first, isNotNull);
    expect(manager.loadMREC(MRECPlacement.search), isNull);
  });

  test('records impression and enforces global cooldown after displayed', () {
    final viewId = manager.loadMREC(MRECPlacement.home)!;
    manager.onAdLoaded(viewId: viewId, placement: MRECPlacement.home);
    manager.showMREC(viewId: viewId, placement: MRECPlacement.home);
    manager.destroyMREC(viewId: viewId, placement: MRECPlacement.home);

    expect(manager.isMRECReady, isFalse);
    // Cooldown is now armed because the ad was DISPLAYED.
    expect(manager.loadMREC(MRECPlacement.discoverFeed), isNull);
  });

  test('does NOT arm cooldown before the ad is actually displayed', () {
    final viewId = manager.loadMREC(MRECPlacement.home)!;
    manager.onAdLoaded(viewId: viewId, placement: MRECPlacement.home);
    manager.destroyMREC(viewId: viewId, placement: MRECPlacement.home);

    expect(manager.isMRECReady, isFalse);
    // No impression was counted -> cooldown is still open -> a new acquire
    // is permitted (the previous slot was released).
    expect(manager.loadMREC(MRECPlacement.search), isNotNull);
  });

  test('load failure releases the slot and does not arm cooldown', () {
    final viewId = manager.loadMREC(MRECPlacement.home)!;
    manager.onAdLoadFailed(
      viewId: viewId,
      placement: MRECPlacement.home,
      error: 'no fill',
    );

    expect(manager.isMRECReady, isFalse);
    expect(manager.loadMREC(MRECPlacement.home), isNotNull);
  });

  test('display is required before an impression is marked', () {
    final viewId = manager.loadMREC(MRECPlacement.home)!;
    manager.onAdLoaded(viewId: viewId, placement: MRECPlacement.home);
    // Before display, no impression -> cooldown remains open.
    expect(manager.loadMREC(MRECPlacement.discoverFeed), isNull,
        reason: 'slot is still held until destroyed');

    manager.showMREC(viewId: viewId, placement: MRECPlacement.home);
    manager.destroyMREC(viewId: viewId, placement: MRECPlacement.home);
    // After display + destroy, cooldown is armed.
    expect(manager.loadMREC(MRECPlacement.search), isNull);
  });

  test('hide without displaying does not arm cooldown', () {
    final viewId = manager.loadMREC(MRECPlacement.home)!;
    manager.onAdLoaded(viewId: viewId, placement: MRECPlacement.home);
    manager.hideMREC(viewId: viewId, placement: MRECPlacement.home);

    expect(manager.loadMREC(MRECPlacement.search), isNotNull);
  });

  test('load timeout constant is bounded and sane', () {
    // Requirement #7: an infinite/blank loading box must be impossible.
    expect(MRECConfig.loadTimeoutSeconds, greaterThan(0));
    expect(MRECConfig.loadTimeoutSeconds, lessThanOrEqualTo(60));
    expect(MRECConfig.width, 300);
    expect(MRECConfig.height, 250);
  });
}

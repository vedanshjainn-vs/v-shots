import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/ads/mrec_ad_manager.dart';

void main() {
  final manager = MRECAdManager.instance;

  setUp(manager.resetForTesting);

  test('allows one MREC load at a time', () {
    final first = manager.loadMREC(MRECPlacement.home);
    expect(first, isNotNull);
    expect(manager.loadMREC(MRECPlacement.search), isNull);
  });

  test('records impression and enforces global cooldown', () {
    final viewId = manager.loadMREC(MRECPlacement.home)!;
    manager.onAdLoaded(viewId: viewId, placement: MRECPlacement.home);
    manager.showMREC(viewId: viewId, placement: MRECPlacement.home);
    manager.destroyMREC(viewId: viewId, placement: MRECPlacement.home);

    expect(manager.isMRECReady, isFalse);
    expect(manager.loadMREC(MRECPlacement.discoverFeed), isNull);
  });
}

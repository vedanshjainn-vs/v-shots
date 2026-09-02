import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/ads/mrec_ad_manager.dart';

void main() {
  final manager = MRECAdManager.instance;

  setUp(() {
    manager.reset();
  });

  test('allows one MREC load at a time', () {
    manager.loadMREC(MRECPlacement.home);
    expect(manager.isLoading, isTrue);
    // Second load should be ignored while loading
    manager.loadMREC(MRECPlacement.search);
    expect(manager.currentPlacement, equals(MRECPlacement.home));
  });

  test('records impression and enforces global cooldown', () {
    manager.loadMREC(MRECPlacement.home);
    manager.markLoaded();
    expect(manager.isLoaded, isTrue);

    manager.markDisplayed();
    expect(manager.isLoaded, isFalse);

    // After display, should enforce cooldown
    manager.loadMREC(MRECPlacement.discoverFeed);
    // Should not load immediately due to cooldown
    expect(manager.isLoading, isFalse);
  });

  test('handles load failure gracefully', () {
    manager.loadMREC(MRECPlacement.home);
    manager.markFailed('test error');
    expect(manager.isLoaded, isFalse);
    expect(manager.error, isNotNull);
  });

  test('reset clears all state', () {
    manager.loadMREC(MRECPlacement.home);
    manager.markLoaded();
    manager.reset();
    expect(manager.isLoaded, isFalse);
    expect(manager.isLoading, isFalse);
    expect(manager.error, isNull);
    expect(manager.currentPlacement, isNull);
  });
}

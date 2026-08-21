import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/playback/vshots_playback_manager.dart';
import 'package:v_shots/core/player/sleep_timer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('playback manager pause() bumps native pauseRequest', () {
    final mgr = VShotsPlaybackManager.instance;
    final before = mgr.browser.pauseRequest.value;
    mgr.pause();
    expect(mgr.browser.pauseRequest.value, before + 1);
  });

  test('sleep timer cancel clears remaining', () {
    SleepTimer.instance.start(const Duration(minutes: 5));
    expect(SleepTimer.instance.isActive, isTrue);
    SleepTimer.instance.cancel();
    expect(SleepTimer.instance.isActive, isFalse);
    expect(SleepTimer.instance.remaining.value, isNull);
  });
}

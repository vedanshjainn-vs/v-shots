import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/remote_config/remote_feature_flags.dart';

void main() {
  tearDown(() {
    RemoteFeatureFlags.instance.debugOverride(null);
  });

  test('safe defaults never enable JioSaavn or social', () {
    RemoteFeatureFlags.instance.debugOverride({});
    expect(RemoteFeatureFlags.instance.enableJioSaavnWebPlayback, isFalse);
    expect(RemoteFeatureFlags.instance.enableJioSaavnSearchFallback, isFalse);
    expect(
      RemoteFeatureFlags.instance.enableDiscoveryRemoteCategories,
      isFalse,
    );
    expect(RemoteFeatureFlags.instance.enableSocial, isFalse);
    expect(RemoteFeatureFlags.instance.enableRemoteHome, isTrue);
  });

  test('override turns JioSaavn on', () {
    RemoteFeatureFlags.instance.debugOverride({
      'enable_jiosaavn_web_playback': true,
      'enable_jiosaavn_search_fallback': true,
    });
    expect(RemoteFeatureFlags.instance.enableJioSaavnWebPlayback, isTrue);
    expect(RemoteFeatureFlags.instance.enableJioSaavnSearchFallback, isTrue);
  });

  test('playbackPolicy mirrors flags', () {
    RemoteFeatureFlags.instance.debugOverride({
      'enable_jiosaavn_web_playback': true,
      'enable_jiosaavn_search_fallback': false,
    });
    final policy = RemoteFeatureFlags.instance.playbackPolicy;
    expect(policy.jiosaavnWebPlayback, isTrue);
    expect(policy.jiosaavnSearchFallback, isFalse);
  });

  test('every required flag key has a default', () {
    const required = [
      'enable_remote_home',
      'enable_jiosaavn_web_playback',
      'enable_jiosaavn_search_fallback',
      'enable_discovery_remote_categories',
      'enable_social',
    ];
    for (final key in required) {
      expect(RemoteFeatureFlags.defaults.containsKey(key), isTrue);
    }
  });
}

from pathlib import Path

ROOT = Path('.')


def patch(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'ads/notification fix anchor not found: {path}')
    p.write_text(text.replace(old, new, 1))


# LevelPlay banner/MREC views must be created only after the SDK's actual
# onInitSuccess callback. The previous implementation completed readyNotifier
# immediately after LevelPlay.init() returned, which could race the callback;
# MREC widgets then saw ready=true but initSucceeded=false and never retried.
patch(
    'lib/core/ads/levelplay_service.dart',
    '''    } catch (e) {
      _initError = e.toString();
      AdAnalytics.log('ad_load_failed', detail: 'LevelPlay.init: $e');
    }
    _completeReady();
    if (_initSucceeded) _preloadIfAllowed();
''',
    '''    } catch (e) {
      _initError = e.toString();
      AdAnalytics.log('ad_load_failed', detail: 'LevelPlay.init: $e');
      _completeReady();
    }
''',
)

patch(
    'lib/core/ads/levelplay_service.dart',
    '''    _createAdObjects();
    // Register impression-level revenue analytics only once the SDK is
''',
    '''    _createAdObjects();
    _completeReady();
    if (_initSucceeded) _preloadIfAllowed();
    // Register impression-level revenue analytics only once the SDK is
''',
)
patch(
    'lib/core/ads/levelplay_service.dart',
    '''  void _onInitFailed(LevelPlayInitError error) {
    _initError = error.toString();
    AdAnalytics.log('ad_load_failed', detail: 'LevelPlay init failed: $error');
  }
''',
    '''  void _onInitFailed(LevelPlayInitError error) {
    _initError = error.toString();
    AdAnalytics.log('ad_load_failed', detail: 'LevelPlay init failed: $error');
    _completeReady();
  }
''',
)

# Prefer a dedicated MREC ad-unit secret, but remain backward compatible with
# the working #399/banner-unit setup. LevelPlay's MREC is the actual
# MEDIUM_RECTANGLE size, not a Flutter placeholder.
patch(
    'lib/core/ads/levelplay_config.dart',
    "    LevelPlayPlacement.bannerHome: 'LEVELPLAY_UNIT_BANNER_HOME_01',\n",
    "    LevelPlayPlacement.bannerHome: 'LEVELPLAY_UNIT_MREC_300X250_01',\n",
)
patch(
    'lib/core/ads/levelplay_config.dart',
    '''    final key = unitEnvKeys[placement];
    if (key == null) return null; // native placements: app-level unit
    return _env(key);
''',
    '''    final key = unitEnvKeys[placement];
    if (key == null) return null; // native placements: app-level unit
    final primary = _env(key);
    if (primary != null) return primary;
    // Backward compatibility with the production LevelPlay unit already used
    // by the working MREC build.
    if (placement == LevelPlayPlacement.bannerHome) {
      return _env('LEVELPLAY_UNIT_BANNER_HOME_01');
    }
    return null;
''',
)

# Revenue-friendly but still user-safe pacing: MREC has enough inventory
# opportunities without stacking multiple visible ads.
patch(
    'lib/core/ads/mrec_ad_manager.dart',
    '  static const int homeInterval = 5;\n',
    '  static const int homeInterval = 4;\n',
)
patch(
    'lib/core/ads/mrec_ad_manager.dart',
    '  static const int cooldownSeconds = 90;\n',
    '  static const int cooldownSeconds = 60;\n',
)

# The scheduled-notification receiver is launched by Android itself after
# reboot/package replacement, so it must be exported on Android 12+.
patch(
    'android/app/src/main/AndroidManifest.xml',
    '''        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
''',
    '''        <receiver
            android:exported="true"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
''',
)

print('Ads + notification reliability patch applied.')

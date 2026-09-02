from pathlib import Path

ROOT = Path('.')


def patch_if_needed(path: str, old: str, new: str) -> None:
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
patch_if_needed(
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
patch_if_needed(
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
patch_if_needed(
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

# Prefer the dedicated MREC unit name when supplied, while retaining the
# already-working production banner-home secret as a backward-compatible
# fallback. MREC size is selected by the actual LevelPlay view.
patch_if_needed(
    'lib/core/ads/levelplay_config.dart',
    "    LevelPlayPlacement.bannerHome: 'LEVELPLAY_UNIT_BANNER_HOME_01',\n",
    "    LevelPlayPlacement.bannerHome: 'LEVELPLAY_UNIT_MREC_300X250_01',\n",
)
patch_if_needed(
    'lib/core/ads/levelplay_config.dart',
    '''    final key = unitEnvKeys[placement];
    if (key == null) return null; // native placements: app-level unit
    return _env(key);
''',
    '''    final key = unitEnvKeys[placement];
    if (key == null) return null; // native placements: app-level unit
    final primary = _env(key);
    if (primary != null) return primary;
    if (placement == LevelPlayPlacement.bannerHome) {
      return _env('LEVELPLAY_UNIT_BANNER_HOME_01');
    }
    return null;
''',
)

# Cadence is tuned in the source to 4 Home / 5 Discover / 3 Search with a
# 60-second global MREC cooldown. No separate patch is needed here.

# Android launches the boot receiver itself after reboot/package replacement;
# Android 12+ requires exported=true for a receiver with a system intent filter.
patch_if_needed(
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

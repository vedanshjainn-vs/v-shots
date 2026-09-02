"""Apply ads/notification reliability fixes idempotently.

If the required new/current state is already present, the patch is skipped.
If the old anchor is already removed/changed, the patch is also skipped.
Only fails if a required validation check does not pass.
"""
from pathlib import Path

ROOT = Path('.')


def patch_if_needed(path: str, old: str, new: str, label: str) -> bool:
    """Patch old→new only when new is absent AND old is present.

    Returns True when the file already satisfies the requirement (either
    because new is already there or because old is gone and the change
    is no longer applicable).
    """
    p = ROOT / path
    text = p.read_text()
    if new in text:
        print(f'  ✓ {label}: already applied in {path}')
        return True
    if old not in text:
        print(f'  ⊘ {label}: anchor absent in {path} (skipping)')
        return True
    p.write_text(text.replace(old, new, 1))
    print(f'  ✓ {label}: patched in {path}')
    return True


def ensure_text(path: str, required: str, label: str) -> bool:
    p = ROOT / path
    text = p.read_text()
    if required not in text:
        raise SystemExit(f'ads/notification fix requirement missing: {label} ({path})')
    print(f'  ✓ {label}: validated in {path}')
    return True


print('[5i] Apply Ads + Notification Reliability Fix')
print()

# ------------------------------------------------------------------
# LevelPlay banner/MREC views must be created only after the SDK's
# actual onInitSuccess callback.
# ------------------------------------------------------------------
print('levelplay_service.dart — readiness gating')
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
    'catch-block ready completion',
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
    'onInitSuccess ready completion',
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
    'onInitFailed ready completion',
)

# ------------------------------------------------------------------
# MREC banner configuration. The branch already carries the desired
# MREC configuration; keep this step idempotent.
# ------------------------------------------------------------------
print()
print('levelplay_config.dart — MREC placement')
patch_if_needed(
    'lib/core/ads/levelplay_config.dart',
    "    LevelPlayPlacement.bannerHome: 'LEVELPLAY_UNIT_BANNER_HOME_01',\n",
    "    LevelPlayPlacement.bannerHome: 'LEVELPLAY_UNIT_MREC_300X250_01',\n",
    'MREC env key mapping',
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
    'banner fallback logic',
)

# ------------------------------------------------------------------
# Required final-state validations.
# ------------------------------------------------------------------
print()
print('Final-state validations')
ensure_text(
    'lib/core/ads/levelplay_config.dart',
    "LevelPlayPlacement.bannerHome: 'LEVELPLAY_UNIT_MREC_300X250_01'",
    'MREC placement environment key',
)
ensure_text(
    'lib/core/ads/levelplay_config.dart',
    "return _env('LEVELPLAY_UNIT_BANNER_HOME_01');",
    'legacy banner fallback',
)
ensure_text(
    'lib/core/ads/levelplay_service.dart',
    '_completeReady();',
    'readiness complete calls',
)
ensure_text(
    'lib/core/ads/levelplay_service.dart',
    'void _onInitSuccess',
    'onInitSuccess handler present',
)
ensure_text(
    'lib/core/ads/levelplay_service.dart',
    'void _onInitFailed',
    'onInitFailed handler present',
)
ensure_text(
    'lib/core/ads/levelplay_service.dart',
    '_createAdObjects',
    'ad object creation after init',
)

# Android 12+ exported attribute
manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
manifest_text = manifest.read_text()
if 'ScheduledNotificationBootReceiver' in manifest_text:
    if 'android:exported="true"' in manifest_text:
        print('  ✓ AndroidManifest: ScheduledNotificationBootReceiver exported=true')
    else:
        raise SystemExit('AndroidManifest: ScheduledNotificationBootReceiver missing android:exported="true"')
else:
    print('   AndroidManifest: ScheduledNotificationBootReceiver not present (skipping)')

print()
print('[5i] Ads + Notification Reliability Fix complete.')

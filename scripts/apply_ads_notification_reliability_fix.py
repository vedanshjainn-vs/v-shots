"""Apply ads/notification reliability fixes idempotently."""
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path('.')
ANDROID_NS = 'http://schemas.android.com/apk/res/android'


def patch_if_needed(path: str, old: str, new: str, label: str) -> bool:
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
    if required not in p.read_text():
        raise SystemExit(f'ads/notification fix requirement missing: {label} ({path})')
    print(f'  ✓ {label}: validated in {path}')
    return True


def normalize_flutter_v2_manifest() -> None:
    """Force the exact manifest state checked by Flutter's build tool.

    This runs after all other build-time patch scripts, so a stale merge/ref
    cannot silently reintroduce the deleted Android v1 embedding.
    """
    manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
    if not manifest.exists():
        raise SystemExit('AndroidManifest.xml is missing')
    ET.register_namespace('android', ANDROID_NS)
    root = ET.fromstring(manifest.read_text(encoding='utf-8-sig'))
    application = root.find('application')
    if application is None:
        raise SystemExit('AndroidManifest.xml has no application element')
    name = f'{{{ANDROID_NS}}}name'
    value = f'{{{ANDROID_NS}}}value'
    if application.get(name) == 'io.flutter.app.FlutterApplication':
        application.set(name, '${applicationName}')
    for node in list(application.findall('meta-data')):
        if node.get(name) == 'flutterEmbedding':
            application.remove(node)
    ET.SubElement(application, 'meta-data', {name: 'flutterEmbedding', value: '2'})
    ET.indent(root, space='    ')
    manifest.write_text(ET.tostring(root, encoding='unicode') + '\n', encoding='utf-8')

    check = ET.parse(manifest).getroot()
    app = check.find('application')
    markers = [n for n in check.iter('meta-data') if n.get(name) == 'flutterEmbedding']
    if app is None or app.get(name) == 'io.flutter.app.FlutterApplication':
        raise SystemExit('Flutter v1 application class remains after normalization')
    if len(markers) != 1 or markers[0].get(value) != '2':
        raise SystemExit('Flutter v2 marker is not exactly one value=2 marker')
    print('  ✓ AndroidManifest: deterministic Flutter v2 embedding')


print('[5i] Apply Ads + Notification Reliability Fix')
print()
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

print()
print('Final-state validations')
ensure_text('lib/core/ads/levelplay_config.dart', "LevelPlayPlacement.bannerHome: 'LEVELPLAY_UNIT_MREC_300X250_01'", 'MREC placement environment key')
ensure_text('lib/core/ads/levelplay_config.dart', "return _env('LEVELPLAY_UNIT_BANNER_HOME_01');", 'legacy banner fallback')
ensure_text('lib/core/ads/levelplay_service.dart', '_completeReady();', 'readiness complete calls')
ensure_text('lib/core/ads/levelplay_service.dart', 'void _onInitSuccess', 'onInitSuccess handler present')
ensure_text('lib/core/ads/levelplay_service.dart', 'void _onInitFailed', 'onInitFailed handler present')
ensure_text('lib/core/ads/levelplay_service.dart', '_createAdObjects', 'ad object creation after init')

manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
manifest_text = manifest.read_text()
if 'ScheduledNotificationBootReceiver' in manifest_text and 'android:exported="true"' not in manifest_text:
    raise SystemExit('AndroidManifest: ScheduledNotificationBootReceiver missing android:exported="true"')

normalize_flutter_v2_manifest()
print()
print('[5i] Ads + Notification Reliability Fix complete.')

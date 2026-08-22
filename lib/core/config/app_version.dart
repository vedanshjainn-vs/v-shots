// ═════════════════════════════════════════════════════════════════════════════
// V Shots — App version from package metadata (not hardcoded)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  AppVersion._();

  static String _versionName = '';
  static String _buildNumber = '';
  static bool _loaded = false;

  static String get versionName => _versionName;
  static String get buildNumber => _buildNumber;

  /// e.g. `Version 5.8.0 (Build 42)` — empty until [load] succeeds.
  static String get displayLabel {
    if (_versionName.isEmpty) return 'Version unknown';
    final build = _buildNumber.isEmpty ? '' : ' (Build $_buildNumber)';
    return 'Version $_versionName$build';
  }

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final info = await PackageInfo.fromPlatform();
      _versionName = info.version;
      _buildNumber = info.buildNumber;
    } catch (_) {
      // Keep unknown — never crash settings.
    }
  }
}

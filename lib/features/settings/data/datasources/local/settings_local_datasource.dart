// ════════════════════════════════════════════════
// Project Lyra — Settings Local Data Source
// ════════════════════════════════════════════════

import '../../../../../core/logging/app_logger.dart';
import '../../../../../core/storage/local_storage.dart';
import '../models/settings_models.dart';

abstract class SettingsLocalDataSource {
  Future<SettingsModel> getSettings();
  Future<void> saveSettings(SettingsModel settings);
  Future<void> clearSettings();
}

class SharedPreferencesSettingsLocalDataSource implements SettingsLocalDataSource {
  SharedPreferencesSettingsLocalDataSource({required this.localStorage, AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final LocalStorage localStorage;
  final AppLogger _logger;

  static const String _settingsKey = 'app_settings';

  @override
  Future<SettingsModel> getSettings() async {
    try {
      return await localStorage.getObject<SettingsModel>(
        _settingsKey,
        SettingsModel.fromJson,
      ) ?? const SettingsModel();
    } catch (e) {
      _logger.w('SettingsLocal: getSettings failed');
      return const SettingsModel();
    }
  }

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    try {
      await localStorage.setObject<SettingsModel>(
        _settingsKey,
        settings,
        (s) => s.toJson(),
      );
    } catch (e) {
      _logger.w('SettingsLocal: saveSettings failed');
    }
  }

  @override
  Future<void> clearSettings() async {
    await localStorage.remove(_settingsKey);
  }
}

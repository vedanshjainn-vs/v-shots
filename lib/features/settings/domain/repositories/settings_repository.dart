// ════════════════════════════════════════════════
// Project Lyra — Settings Repository Interface
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/settings_entities.dart';

typedef Result<T> = Either<Failure, T>;

abstract class SettingsRepository {
  Future<Result<AppSettings>> getSettings();
  Future<Result<AppSettings>> updateTheme(ThemeMode themeMode);
  Future<Result<AppSettings>> updateAudioQuality(AudioQuality quality);
  Future<Result<AppSettings>> updateDownloadQuality(AudioQuality quality);
  Future<Result<AppSettings>> updateLanguage(String language);
  Future<Result<AppSettings>> updateDownloadOverWifi(bool value);
  Future<Result<AppSettings>> updateNotifications(bool enabled);
  Future<Result<AppSettings>> updateExplicitContent(bool show);
  Future<Result<AppSettings>> updateCrossfade(bool enabled, {Duration? duration});
  Future<Result<AppSettings>> updateGaplessPlayback(bool enabled);
  Future<Result<void>> resetToDefaults();
  Stream<AppSettings> get settingsStream;
}

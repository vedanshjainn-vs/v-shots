// ════════════════════════════════════════════════
// Project Lyra — Settings Repository Implementation
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/mapper/failure_mapper.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/settings_entities.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/local/settings_local_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    required this.localDataSource,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final SettingsLocalDataSource localDataSource;
  final AppLogger _logger;

  AppSettings? _cachedSettings;

  @override
  Future<Either<Failure, AppSettings>> getSettings() async {
    try {
      if (_cachedSettings != null) return Right(_cachedSettings!);

      final settings = await localDataSource.getSettings();
      _cachedSettings = settings.toEntity();
      return Right(_cachedSettings!);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, AppSettings>> updateTheme(ThemeMode themeMode) async {
    try {
      final current = await _getOrCreateSettings();
      final updated = current.copyWith(themeMode: themeMode);
      await _save(updated);
      return Right(updated);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, AppSettings>> updateAudioQuality(AudioQuality quality) async {
    try {
      final current = await _getOrCreateSettings();
      final updated = current.copyWith(audioQuality: quality);
      await _save(updated);
      return Right(updated);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, AppSettings>> updateDownloadQuality(AudioQuality quality) async {
    try {
      final current = await _getOrCreateSettings();
      final updated = current.copyWith(downloadQuality: quality);
      await _save(updated);
      return Right(updated);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, AppSettings>> updateLanguage(String language) async {
    try {
      final current = await _getOrCreateSettings();
      final updated = current.copyWith(language: language);
      await _save(updated);
      return Right(updated);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, AppSettings>> updateDownloadOverWifi(bool value) async {
    try {
      final current = await _getOrCreateSettings();
      final updated = current.copyWith(downloadOverWifiOnly: value);
      await _save(updated);
      return Right(updated);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, AppSettings>> updateNotifications(bool enabled) async {
    try {
      final current = await _getOrCreateSettings();
      final updated = current.copyWith(notificationsEnabled: enabled);
      await _save(updated);
      return Right(updated);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, AppSettings>> updateExplicitContent(bool show) async {
    try {
      final current = await _getOrCreateSettings();
      final updated = current.copyWith(showExplicitContent: show);
      await _save(updated);
      return Right(updated);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, AppSettings>> updateCrossfade(bool enabled, {Duration? duration}) async {
    try {
      final current = await _getOrCreateSettings();
      final updated = current.copyWith(
        crossfadeEnabled: enabled,
        crossfadeDuration: duration ?? current.crossfadeDuration,
      );
      await _save(updated);
      return Right(updated);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, AppSettings>> updateGaplessPlayback(bool enabled) async {
    try {
      final current = await _getOrCreateSettings();
      final updated = current.copyWith(gaplessPlayback: enabled);
      await _save(updated);
      return Right(updated);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> resetToDefaults() async {
    try {
      const defaults = AppSettings();
      await _save(defaults);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Stream<AppSettings> get settingsStream => const Stream.empty();

  Future<AppSettings> _getOrCreateSettings() async {
    if (_cachedSettings != null) return _cachedSettings!;
    final model = await localDataSource.getSettings();
    _cachedSettings = model.toEntity();
    return _cachedSettings!;
  }

  Future<void> _save(AppSettings settings) async {
    _cachedSettings = settings;
    await localDataSource.saveSettings(settings.toModel());
  }
}

// ════════════════════════════════════════════════
// Project Lyra — Settings Use Cases
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/settings_entities.dart';
import '../repositories/settings_repository.dart';

class GetSettings implements UseCase<AppSettings, NoParams> {
  const GetSettings(this.repository);
  final SettingsRepository repository;
  @override
  Future<Either<Failure, AppSettings>> call(NoParams params) => repository.getSettings();
}

class UpdateTheme implements UseCase<AppSettings, ThemeMode> {
  const UpdateTheme(this.repository);
  final SettingsRepository repository;
  @override
  Future<Either<Failure, AppSettings>> call(ThemeMode mode) => repository.updateTheme(mode);
}

class UpdateAudioQuality implements UseCase<AppSettings, AudioQuality> {
  const UpdateAudioQuality(this.repository);
  final SettingsRepository repository;
  @override
  Future<Either<Failure, AppSettings>> call(AudioQuality quality) =>
      repository.updateAudioQuality(quality);
}

class UpdateLanguage implements UseCase<AppSettings, String> {
  const UpdateLanguage(this.repository);
  final SettingsRepository repository;
  @override
  Future<Either<Failure, AppSettings>> call(String language) =>
      repository.updateLanguage(language);
}

class ResetSettings implements UseCaseVoid<NoParams> {
  const ResetSettings(this.repository);
  final SettingsRepository repository;
  @override
  Future<Either<Failure, void>> call(NoParams params) => repository.resetToDefaults();
}

// ════════════════════════════════════════════════
// Project Lyra — Settings Data Models
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/settings_entities.dart';

part 'settings_models.freezed.dart';
part 'settings_models.g.dart';

@freezed
class SettingsModel with _$SettingsModel {
  const factory SettingsModel({
    @Default('dark') String themeMode,
    @Default('high') String audioQuality,
    @Default('high') String downloadQuality,
    @Default('en') String language,
    @Default(true) bool downloadOverWifiOnly,
    @Default(true) bool notificationsEnabled,
    @Default(true) bool analyticsEnabled,
    @Default(false) bool crossfadeEnabled,
    @Default(3000) int crossfadeDurationMs,
    @Default(true) bool gaplessPlayback,
    @Default(true) bool normalizeVolume,
    @Default(true) bool showExplicitContent,
  }) = _SettingsModel;

  factory SettingsModel.fromJson(Map<String, dynamic> json) => _$SettingsModelFromJson(json);
}

/// Entity conversion extension.
extension SettingsModelX on SettingsModel {
  AppSettings toEntity() => AppSettings(
        themeMode: ThemeMode.values.byName(themeMode),
        audioQuality: AudioQuality.values.byName(audioQuality),
        downloadQuality: AudioQuality.values.byName(downloadQuality),
        language: language,
        downloadOverWifiOnly: downloadOverWifiOnly,
        notificationsEnabled: notificationsEnabled,
        analyticsEnabled: analyticsEnabled,
        crossfadeEnabled: crossfadeEnabled,
        crossfadeDuration: Duration(milliseconds: crossfadeDurationMs),
        gaplessPlayback: gaplessPlayback,
        normalizeVolume: normalizeVolume,
        showExplicitContent: showExplicitContent,
      );
}

/// Convert entity to model for persistence.
extension AppSettingsEntityX on AppSettings {
  SettingsModel toModel() => SettingsModel(
        themeMode: themeMode.name,
        audioQuality: audioQuality.name,
        downloadQuality: downloadQuality.name,
        language: language,
        downloadOverWifiOnly: downloadOverWifiOnly,
        notificationsEnabled: notificationsEnabled,
        analyticsEnabled: analyticsEnabled,
        crossfadeEnabled: crossfadeEnabled,
        crossfadeDurationMs: crossfadeDuration.inMilliseconds,
        gaplessPlayback: gaplessPlayback,
        normalizeVolume: normalizeVolume,
        showExplicitContent: showExplicitContent,
      );
}

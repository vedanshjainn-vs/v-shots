// ════════════════════════════════════════════════
// Project Lyra — Settings Entities
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_entities.freezed.dart';
part 'settings_entities.g.dart';

@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(ThemeMode.dark) ThemeMode themeMode,
    @Default(AudioQuality.high) AudioQuality audioQuality,
    @Default(AudioQuality.high) AudioQuality downloadQuality,
    @Default('en') String language,
    @Default(true) bool downloadOverWifiOnly,
    @Default(true) bool notificationsEnabled,
    @Default(true) bool analyticsEnabled,
    @Default(false) bool crossfadeEnabled,
    @Default(Duration(seconds: 3)) Duration crossfadeDuration,
    @Default(true) bool gaplessPlayback,
    @Default(true) bool normalizeVolume,
    @Default(true) bool showExplicitContent,
    @Default(false) bool highContrastMode,
    @Default(1.0) double textScale,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);
}

enum ThemeMode { system, light, dark }

enum AudioQuality {
  low(96, 'Low'),
  normal(128, 'Normal'),
  high(256, 'High'),
  lossless(320, 'Lossless');

  const AudioQuality(this.bitrate, this.label);
  final int bitrate;
  final String label;
}

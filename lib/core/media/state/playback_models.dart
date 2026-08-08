// ════════════════════════════════════════════════
// Project Lyra — Playback Models
// ════════════════════════════════════════════════
//
// Core data models for the media playback system.
// Immutable, serializable, and extensible.
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'playback_models.freezed.dart';
part 'playback_models.g.dart';

/// A track in the playback queue.
@freezed
class QueueItem with _$QueueItem {
  const factory QueueItem({
    required String id,
    required String title,
    required String artist,
    String? album,
    String? artUrl,
    String? streamUrl,
    @Default(Duration.zero) Duration duration,
    @Default(false) bool isOffline,
    @Default({}) Map<String, dynamic> metadata,
  }) = _QueueItem;

  factory QueueItem.fromJson(Map<String, dynamic> json) =>
      _$QueueItemFromJson(json);
}

/// Current playback state.
@freezed
class PlaybackStateModel with _$PlaybackStateModel {
  const factory PlaybackStateModel({
    @Default(PlayerStatus.idle) PlayerStatus status,
    @Default(Duration.zero) Duration position,
    @Default(Duration.zero) Duration duration,
    @Default(Duration.zero) Duration bufferedPosition,
    @Default(1.0) double speed,
    @Default(RepeatMode.off) RepeatMode repeatMode,
    @Default(false) bool shuffleEnabled,
    @Default(1.0) double volume,
    QueueItem? currentTrack,
    @Default(0) int currentIndex,
    @Default(0) int queueLength,
    String? error,
  }) = _PlaybackStateModel;

  factory PlaybackStateModel.fromJson(Map<String, dynamic> json) =>
      _$PlaybackStateModelFromJson(json);
}

/// Player status.
enum PlayerStatus {
  idle,
  loading,
  buffering,
  playing,
  paused,
  stopped,
  error,
  completed,
}

/// Repeat modes.
enum RepeatMode {
  off,
  one,
  all,
}

/// Audio quality levels.
enum AudioQuality {
  low(96, 'Low'),
  normal(128, 'Normal'),
  high(256, 'High'),
  lossless(320, 'Lossless');

  const AudioQuality(this.bitrate, this.label);
  final int bitrate;
  final String label;
}

/// Crossfade configuration.
@freezed
class CrossfadeConfig with _$CrossfadeConfig {
  const factory CrossfadeConfig({
    @Default(false) bool enabled,
    @Default(Duration(seconds: 3)) Duration duration,
    @Default(0.5) double curve,
  }) = _CrossfadeConfig;

  factory CrossfadeConfig.fromJson(Map<String, dynamic> json) =>
      _$CrossfadeConfigFromJson(json);
}

/// Equalizer band configuration.
@freezed
class EqualizerBand with _$EqualizerBand {
  const factory EqualizerBand({
    required String name,
    required double frequency,
    @Default(0.0) double gain,
    @Default(-12.0) double minGain,
    @Default(12.0) double maxGain,
  }) = _EqualizerBand;

  factory EqualizerBand.fromJson(Map<String, dynamic> json) =>
      _$EqualizerBandFromJson(json);
}

/// Equalizer preset.
@freezed
class EqualizerPreset with _$EqualizerPreset {
  const factory EqualizerPreset({
    required String id,
    required String name,
    required List<EqualizerBand> bands,
    @Default(false) bool isCustom,
  }) = _EqualizerPreset;

  factory EqualizerPreset.fromJson(Map<String, dynamic> json) =>
      _$EqualizerPresetFromJson(json);
}

/// Sleep timer configuration.
@freezed
class SleepTimerConfig with _$SleepTimerConfig {
  const factory SleepTimerConfig({
    @Default(false) bool active,
    Duration? remaining,
    Duration? totalDuration,
    @Default(false) bool fadeOut,
    @Default(false) bool endOfTrack,
  }) = _SleepTimerConfig;

  factory SleepTimerConfig.fromJson(Map<String, dynamic> json) =>
      _$SleepTimerConfigFromJson(json);
}

/// Lyrics line.
@freezed
class LyricsLine with _$LyricsLine {
  const factory LyricsLine({
    required String text,
    required Duration timestamp,
    @Default(false) bool isChorus,
    String? translation,
  }) = _LyricsLine;

  factory LyricsLine.fromJson(Map<String, dynamic> json) =>
      _$LyricsLineFromJson(json);
}

/// Full lyrics data.
@freezed
class LyricsData with _$LyricsData {
  const factory LyricsData({
    required String trackId,
    required List<LyricsLine> lines,
    @Default(false) bool isSynced,
    @Default(false) bool isRightToLeft,
    String? source,
    String? language,
  }) = _LyricsData;

  factory LyricsData.fromJson(Map<String, dynamic> json) =>
      _$LyricsDataFromJson(json);
}

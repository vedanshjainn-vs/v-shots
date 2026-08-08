// ════════════════════════════════════════════════
// Project Lyra — Download Data Models
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/download_entities.dart';

part 'download_models.freezed.dart';
part 'download_models.g.dart';

@freezed
class DownloadModel with _$DownloadModel {
  const factory DownloadModel({
    required String id,
    required String trackId,
    required String title,
    required String artist,
    String? album,
    String? artUrl,
    String? filePath,
    @Default('queued') String status,
    @Default(0.0) double progress,
    @Default(0) int totalBytes,
    @Default(0) int downloadedBytes,
    @Default(320) int bitrate,
    String? error,
    @Default(0) int retryCount,
    String? startedAt,
    String? completedAt,
  }) = _DownloadModel;

  factory DownloadModel.fromJson(Map<String, dynamic> json) => _$DownloadModelFromJson(json);
}

/// Entity conversion extension.
extension DownloadModelX on DownloadModel {
  Download toEntity() => Download(
        id: id, trackId: trackId, title: title, artist: artist,
        album: album, artUrl: artUrl, filePath: filePath,
        status: DownloadStatus.values.byName(status),
        progress: progress, totalBytes: totalBytes,
        downloadedBytes: downloadedBytes, bitrate: bitrate,
        error: error, retryCount: retryCount,
        startedAt: startedAt != null ? DateTime.tryParse(startedAt!) : null,
        completedAt: completedAt != null ? DateTime.tryParse(completedAt!) : null,
      );
}

/// Convert entity to model for persistence.
extension DownloadEntityX on Download {
  DownloadModel toModel() => DownloadModel(
        id: id, trackId: trackId, title: title, artist: artist,
        album: album, artUrl: artUrl, filePath: filePath,
        status: status.name, progress: progress,
        totalBytes: totalBytes, downloadedBytes: downloadedBytes,
        bitrate: bitrate, error: error, retryCount: retryCount,
        startedAt: startedAt?.toIso8601String(),
        completedAt: completedAt?.toIso8601String(),
      );
}

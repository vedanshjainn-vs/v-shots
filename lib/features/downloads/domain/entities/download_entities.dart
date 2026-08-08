// ════════════════════════════════════════════════
// Project Lyra — Download Entities
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'download_entities.freezed.dart';
part 'download_entities.g.dart';

@freezed
class Download with _$Download {
  const factory Download({
    required String id,
    required String trackId,
    required String title,
    required String artist,
    String? album,
    String? artUrl,
    String? filePath,
    @Default(DownloadStatus.queued) DownloadStatus status,
    @Default(0.0) double progress,
    @Default(0) int totalBytes,
    @Default(0) int downloadedBytes,
    @Default(0) int bitrate,
    String? error,
    @Default(0) int retryCount,
    DateTime? startedAt,
    DateTime? completedAt,
  }) = _Download;

  factory Download.fromJson(Map<String, dynamic> json) => _$DownloadFromJson(json);
}

@freezed
class DownloadGroup with _$DownloadGroup {
  const factory DownloadGroup({
    required String id,
    required String title,
    String? artUrl,
    @Default([]) List<Download> downloads,
    @Default(0) int totalSize,
    DateTime? createdAt,
  }) = _DownloadGroup;

  factory DownloadGroup.fromJson(Map<String, dynamic> json) => _$DownloadGroupFromJson(json);
}

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled;

  bool get isActive => this == downloading || this == queued;
  bool get isTerminal => this == completed || this == failed || this == cancelled;
}

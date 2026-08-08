// ════════════════════════════════════════════════
// Project Lyra — Download Task
// ════════════════════════════════════════════════
//
// Immutable model representing a single download
// task with progress tracking and metadata.
// ════════════════════════════════════════════════

import 'package:equatable/equatable.dart';

import 'download_status.dart';

/// Represents a single download task.
///
/// Immutable — use [copyWith] to create updated versions.
/// Tracks status, progress, and metadata throughout
/// the download lifecycle.
class DownloadTask extends Equatable {
  /// Creates a download task.
  const DownloadTask({
    required this.id,
    required this.url,
    required this.type,
    required this.title,
    this.artist,
    this.artUrl,
    this.filePath,
    this.status = DownloadStatus.queued,
    this.priority = DownloadPriority.normal,
    this.progress = 0.0,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.speedBytesPerSecond = 0,
    this.error,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.createdAt,
    this.startedAt,
    this.completedAt,
    this.metadata = const {},
  });

  /// Unique identifier for this download.
  final String id;

  /// URL to download from.
  final String url;

  /// Type of content being downloaded.
  final DownloadType type;

  /// Human-readable title for the download.
  final String title;

  /// Artist / creator name.
  final String? artist;

  /// Artwork URL.
  final String? artUrl;

  /// Local file path where the download is stored.
  final String? filePath;

  /// Current download status.
  final DownloadStatus status;

  /// Download priority.
  final DownloadPriority priority;

  /// Download progress (0.0 to 1.0).
  final double progress;

  /// Total file size in bytes.
  final int totalBytes;

  /// Bytes downloaded so far.
  final int downloadedBytes;

  /// Current download speed in bytes/second.
  final int speedBytesPerSecond;

  /// Error message if download failed.
  final String? error;

  /// Number of retry attempts.
  final int retryCount;

  /// Maximum retry attempts before permanent failure.
  final int maxRetries;

  /// When the task was created.
  final DateTime? createdAt;

  /// When the download started.
  final DateTime? startedAt;

  /// When the download completed.
  final DateTime? completedAt;

  /// Additional metadata (quality, codec, etc.).
  final Map<String, dynamic> metadata;

  /// Whether the download has finished (success or failure).
  bool get isFinished => status.isTerminal;

  /// Whether the download can be retried.
  bool get canRetry => status == DownloadStatus.failed && retryCount < maxRetries;

  /// Estimated time remaining.
  Duration? get estimatedTimeRemaining {
    if (speedBytesPerSecond <= 0 || totalBytes <= 0) return null;
    final remainingBytes = totalBytes - downloadedBytes;
    final seconds = remainingBytes / speedBytesPerSecond;
    return Duration(seconds: seconds.ceil());
  }

  /// Create a copy with updated fields.
  DownloadTask copyWith({
    DownloadStatus? status,
    DownloadPriority? priority,
    double? progress,
    int? totalBytes,
    int? downloadedBytes,
    int? speedBytesPerSecond,
    String? filePath,
    String? error,
    int? retryCount,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: id,
      url: url,
      type: type,
      title: title,
      artist: artist,
      artUrl: artUrl,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      progress: progress ?? this.progress,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      error: error ?? this.error,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      metadata: metadata,
    );
  }

  /// Serialize to JSON for persistence.
  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'type': type.name,
        'title': title,
        'artist': artist,
        'artUrl': artUrl,
        'filePath': filePath,
        'status': status.name,
        'priority': priority.name,
        'progress': progress,
        'totalBytes': totalBytes,
        'downloadedBytes': downloadedBytes,
        'error': error,
        'retryCount': retryCount,
        'maxRetries': maxRetries,
        'createdAt': createdAt?.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'metadata': metadata,
      };

  /// Deserialize from JSON.
  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      url: json['url'] as String,
      type: DownloadType.values.byName(json['type'] as String),
      title: json['title'] as String,
      artist: json['artist'] as String?,
      artUrl: json['artUrl'] as String?,
      filePath: json['filePath'] as String?,
      status: DownloadStatus.values.byName(json['status'] as String),
      priority: DownloadPriority.values.byName(json['priority'] as String),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      error: json['error'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
      maxRetries: json['maxRetries'] as int? ?? 3,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  @override
  List<Object?> get props => [id, status, progress, downloadedBytes];
}

// ════════════════════════════════════════════════
// Project Lyra — Download Status & Priority
// ════════════════════════════════════════════════

/// Status of a download task.
enum DownloadStatus {
  /// Queued but not started.
  queued,

  /// Waiting for network / permissions.
  waiting,

  /// Currently downloading.
  downloading,

  /// Download paused by user or system.
  paused,

  /// Download completed successfully.
  completed,

  /// Download failed.
  failed,

  /// Download cancelled by user.
  cancelled;

  bool get isActive => this == downloading || this == queued || this == waiting;
  bool get isTerminal => this == completed || this == failed || this == cancelled;
  bool get canResume => this == paused || this == failed;
  bool get canPause => this == downloading || this == queued || this == waiting;
  bool get canCancel => !isTerminal;
}

/// Priority of a download task.
enum DownloadPriority {
  /// Low priority — download when idle.
  low(0),

  /// Normal priority — default.
  normal(1),

  /// High priority — download before normal tasks.
  high(2),

  /// Critical — download immediately (e.g., user-initiated).
  critical(3);

  const DownloadPriority(this.value);

  /// Numeric value for sorting (higher = more important).
  final int value;
}

/// Type of content being downloaded.
enum DownloadType {
  /// Music track.
  track,

  /// Podcast episode.
  podcastEpisode,

  /// Audiobook chapter.
  audiobookChapter,

  /// Image/artwork.
  image;
}

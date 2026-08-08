// ════════════════════════════════════════════════
// Project Lyra — Application Events
// ════════════════════════════════════════════════
//
// Typed events for the application event bus.
// Organized by domain: auth, playback, connectivity, etc.
// ════════════════════════════════════════════════

/// Base class for all application events.
///
/// All events must extend this class for type-safe
/// dispatching on the event bus.
sealed class AppEvent {
  const AppEvent();

  /// When this event occurred.
  DateTime get timestamp => DateTime.now();
}

// ── Authentication Events ─────────────────────

/// User successfully signed in.
class UserSignedInEvent extends AppEvent {
  const UserSignedInEvent({required this.userId, this.method});
  final String userId;
  final String? method;
}

/// User signed out.
class UserSignedOutEvent extends AppEvent {
  const UserSignedOutEvent({this.reason});
  final String? reason;
}

/// Auth token was refreshed.
class TokenRefreshedEvent extends AppEvent {
  const TokenRefreshedEvent();
}

/// Auth token expired.
class TokenExpiredEvent extends AppEvent {
  const TokenExpiredEvent();
}

// ── Playback Events ───────────────────────────

/// A track started playing.
class TrackPlayedEvent extends AppEvent {
  const TrackPlayedEvent({
    required this.trackId,
    required this.title,
    this.artist,
    this.source,
  });
  final String trackId;
  final String title;
  final String? artist;
  final String? source;
}

/// Playback was paused.
class PlaybackPausedEvent extends AppEvent {
  const PlaybackPausedEvent({required this.trackId});
  final String trackId;
}

/// Playback was resumed.
class PlaybackResumedEvent extends AppEvent {
  const PlaybackResumedEvent({required this.trackId});
  final String trackId;
}

/// Track skipped.
class TrackSkippedEvent extends AppEvent {
  const TrackSkippedEvent({
    required this.trackId,
    this.direction = SkipDirection.next,
  });
  final String trackId;
  final SkipDirection direction;
}

/// Playback queue modified.
class QueueModifiedEvent extends AppEvent {
  const QueueModifiedEvent({required this.queueLength});
  final int queueLength;
}

enum SkipDirection { next, previous }

// ── Library Events ────────────────────────────

/// User liked a track.
class TrackLikedEvent extends AppEvent {
  const TrackLikedEvent({required this.trackId});
  final String trackId;
}

/// User unliked a track.
class TrackUnlikedEvent extends AppEvent {
  const TrackUnlikedEvent({required this.trackId});
  final String trackId;
}

/// User saved content to library.
class ContentSavedEvent extends AppEvent {
  const ContentSavedEvent({
    required this.contentId,
    required this.contentType,
  });
  final String contentId;
  final String contentType;
}

// ── Connectivity Events ───────────────────────

/// Device came online.
class ConnectivityRestoredEvent extends AppEvent {
  const ConnectivityRestoredEvent();
}

/// Device went offline.
class ConnectivityLostEvent extends AppEvent {
  const ConnectivityLostEvent();
}

// ── Download Events ───────────────────────────

/// Download started.
class DownloadStartedEvent extends AppEvent {
  const DownloadStartedEvent({required this.downloadId, required this.title});
  final String downloadId;
  final String title;
}

/// Download completed.
class DownloadCompletedEvent extends AppEvent {
  const DownloadCompletedEvent({
    required this.downloadId,
    required this.filePath,
  });
  final String downloadId;
  final String filePath;
}

/// Download failed.
class DownloadFailedEvent extends AppEvent {
  const DownloadFailedEvent({
    required this.downloadId,
    this.error,
  });
  final String downloadId;
  final String? error;
}

// ── Sync Events ───────────────────────────────

/// Sync started.
class SyncStartedEvent extends AppEvent {
  const SyncStartedEvent();
}

/// Sync completed.
class SyncCompletedEvent extends AppEvent {
  const SyncCompletedEvent({required this.itemsSynced});
  final int itemsSynced;
}

/// Sync failed.
class SyncFailedEvent extends AppEvent {
  const SyncFailedEvent({required this.error});
  final String error;
}

// ── App Lifecycle Events ──────────────────────

/// App came to foreground.
class AppResumedEvent extends AppEvent {
  const AppResumedEvent();
}

/// App went to background.
class AppPausedEvent extends AppEvent {
  const AppPausedEvent();
}

/// App started (cold start).
class AppStartedEvent extends AppEvent {
  const AppStartedEvent();
}

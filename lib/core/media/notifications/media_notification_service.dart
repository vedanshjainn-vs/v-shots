// ════════════════════════════════════════════════
// Project Lyra — Media Notification Service
// ════════════════════════════════════════════════
//
// Manages the Android media notification.
// Shows track info, artwork, and playback controls.
// Integrates with MediaSession for system controls.
// Architecture only — no implementation yet.
// ════════════════════════════════════════════════

import '../state/playback_models.dart';

/// Service for managing media notifications.
///
/// Shows the persistent notification with:
/// - Track title, artist, album art
/// - Play/pause, skip, previous buttons
/// - Progress bar
/// - Favorite button
abstract class MediaNotificationService {
  /// Initialize the notification channel and MediaSession.
  Future<void> initialize();

  /// Update the notification with current track info.
  Future<void> update({
    required QueueItem track,
    required PlayerStatus status,
    required Duration position,
    required Duration duration,
    bool isLiked = false,
  });

  /// Show a notification for a loading state.
  Future<void> showLoading({String? message});

  /// Clear the notification.
  Future<void> clear();

  /// Stream of notification action events.
  Stream<MediaNotificationAction> get actionStream;

  /// Dispose resources.
  Future<void> dispose();
}

/// Actions from the media notification.
enum MediaNotificationAction {
  play,
  pause,
  next,
  previous,
  stop,
  seekForward,
  seekBackward,
  favorite,
  shuffle,
  repeat,
}

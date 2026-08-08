// ════════════════════════════════════════════════
// Project Lyra — Notification Payload
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_payload.freezed.dart';
part 'notification_payload.g.dart';

/// Structured notification payload.
///
/// Maps to deep-link destinations when user taps
/// a push notification.
@freezed
class NotificationPayload with _$NotificationPayload {
  const factory NotificationPayload({
    required String type,
    String? id,
    String? title,
    String? body,
    String? imageUrl,
    @Default({}) Map<String, dynamic> data,
  }) = _NotificationPayload;

  factory NotificationPayload.fromJson(Map<String, dynamic> json) =>
      _$NotificationPayloadFromJson(json);
}

/// Notification type constants.
abstract final class NotificationTypes {
  static const String newRelease = 'new_release';
  static const String newEpisode = 'new_episode';
  static const String playlistUpdate = 'playlist_update';
  static const String artistUpdate = 'artist_update';
  static const String recommendation = 'recommendation';
  static const String promotion = 'promotion';
  static const String system = 'system';
}

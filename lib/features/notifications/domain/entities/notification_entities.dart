// ════════════════════════════════════════════════
// Project Lyra — Notification Entities
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_entities.freezed.dart';
part 'notification_entities.g.dart';

@freezed
class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    required String title,
    String? body,
    required NotificationType type,
    String? imageUrl,
    String? actionUrl,
    @Default(false) bool isRead,
    DateTime? createdAt,
    @Default({}) Map<String, dynamic> data,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) => _$AppNotificationFromJson(json);
}

@freezed
class NotificationSettings with _$NotificationSettings {
  const factory NotificationSettings({
    @Default(true) bool pushEnabled,
    @Default(true) bool newReleases,
    @Default(true) bool playlistUpdates,
    @Default(true) bool artistUpdates,
    @Default(true) bool recommendations,
    @Default(false) bool promotions,
    @Default(true) bool socialActivity,
  }) = _NotificationSettings;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) => _$NotificationSettingsFromJson(json);
}

enum NotificationType {
  newRelease,
  playlistUpdate,
  artistUpdate,
  recommendation,
  promotion,
  social,
  system,
}

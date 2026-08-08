// ════════════════════════════════════════════════
// Project Lyra — Notification Data Models
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/notification_entities.dart';

part 'notification_models.freezed.dart';
part 'notification_models.g.dart';

@freezed
class NotificationModel with _$NotificationModel {
  const factory NotificationModel({
    required String id,
    required String title,
    String? body,
    required String type,
    String? imageUrl,
    String? actionUrl,
    @Default(false) bool isRead,
    String? createdAt,
    @Default({}) Map<String, dynamic> data,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) => _$NotificationModelFromJson(json);
}

@freezed
class NotificationSettingsModel with _$NotificationSettingsModel {
  const factory NotificationSettingsModel({
    @Default(true) bool pushEnabled,
    @Default(true) bool newReleases,
    @Default(true) bool playlistUpdates,
    @Default(true) bool artistUpdates,
    @Default(true) bool recommendations,
    @Default(false) bool promotions,
    @Default(true) bool socialActivity,
  }) = _NotificationSettingsModel;

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) => _$NotificationSettingsModelFromJson(json);
}

/// Entity conversion extensions.
extension NotificationModelX on NotificationModel {
  AppNotification toEntity() => AppNotification(
        id: id, title: title, body: body,
        type: NotificationType.values.byName(type),
        imageUrl: imageUrl, actionUrl: actionUrl, isRead: isRead,
        createdAt: createdAt != null ? DateTime.tryParse(createdAt!) : null,
        data: data,
      );
}

extension NotificationSettingsModelX on NotificationSettingsModel {
  NotificationSettings toEntity() => NotificationSettings(
        pushEnabled: pushEnabled, newReleases: newReleases,
        playlistUpdates: playlistUpdates, artistUpdates: artistUpdates,
        recommendations: recommendations, promotions: promotions,
        socialActivity: socialActivity,
      );
}

extension NotificationSettingsEntityX on NotificationSettings {
  NotificationSettingsModel toModel() => NotificationSettingsModel(
        pushEnabled: pushEnabled, newReleases: newReleases,
        playlistUpdates: playlistUpdates, artistUpdates: artistUpdates,
        recommendations: recommendations, promotions: promotions,
        socialActivity: socialActivity,
      );
}

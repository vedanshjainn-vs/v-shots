// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Notification Model
// ═════════════════════════════════════════════════════════════════════════════

import 'profile_model.dart';

enum NotificationType { like, comment, follow, mention, system }

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    this.shotId,
    this.read = false,
    this.actor,
    this.createdAt,
  });

  final String id;
  final String recipientId;
  final String actorId;
  final NotificationType type;
  final String? shotId;
  final bool read;
  final ProfileModel? actor;
  final DateTime? createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    ProfileModel? actor;
    if (json['actor'] != null && json['actor'] is Map<String, dynamic>) {
      actor = ProfileModel.fromJson(json['actor'] as Map<String, dynamic>);
    } else if (json['profiles'] != null && json['profiles'] is Map<String, dynamic>) {
      actor = ProfileModel.fromJson(json['profiles'] as Map<String, dynamic>);
    }

    final rawType = json['type'] as String? ?? 'like';
    NotificationType notifType;
    switch (rawType) {
      case 'comment':
        notifType = NotificationType.comment;
        break;
      case 'follow':
        notifType = NotificationType.follow;
        break;
      case 'mention':
        notifType = NotificationType.mention;
        break;
      case 'system':
        notifType = NotificationType.system;
        break;
      case 'like':
      default:
        notifType = NotificationType.like;
        break;
    }

    return NotificationModel(
      id: json['id'] as String? ?? '',
      recipientId: json['recipient_id'] as String? ?? '',
      actorId: json['actor_id'] as String? ?? '',
      type: notifType,
      shotId: json['shot_id'] as String?,
      read: json['read'] as bool? ?? false,
      actor: actor,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

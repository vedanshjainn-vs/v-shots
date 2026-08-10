// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Notifications Service
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import '../backend/supabase_service.dart';
import '../models/notification_model.dart';
import '../models/profile_model.dart';

class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  final List<NotificationModel> _mockNotifications = <NotificationModel>[
    NotificationModel(
      id: 'notif-1',
      recipientId: 'self',
      actorId: 'mock-creator-1',
      type: NotificationType.like,
      shotId: 'mock-1',
      read: false,
      actor: const ProfileModel(
        id: 'mock-creator-1',
        username: 'novadesign',
        fullName: 'Nova Studio',
        avatarUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&q=80',
      ),
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    NotificationModel(
      id: 'notif-2',
      recipientId: 'self',
      actorId: 'mock-creator-2',
      type: NotificationType.comment,
      shotId: 'mock-1',
      read: false,
      actor: const ProfileModel(
        id: 'mock-creator-2',
        username: 'arialuna',
        fullName: 'Aria Luna',
        avatarUrl:
            'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&q=80',
      ),
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    NotificationModel(
      id: 'notif-3',
      recipientId: 'self',
      actorId: 'mock-creator-3',
      type: NotificationType.follow,
      read: true,
      actor: const ProfileModel(
        id: 'mock-creator-3',
        username: 'neonpulse',
        fullName: 'Kenji Sato',
        avatarUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&q=80',
      ),
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  Future<List<NotificationModel>> fetchNotifications() async {
    final user = SupabaseService.currentUser;
    if (!SupabaseService.isAvailable || user == null) {
      return List<NotificationModel>.from(_mockNotifications);
    }

    try {
      final response = await SupabaseService.client
          .from('notifications')
          .select('*, profiles:actor_id(*)')
          .eq('recipient_id', user.id)
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;
      if (data.isEmpty) {
        return List<NotificationModel>.from(_mockNotifications);
      }
      return data
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[NotificationsService] fetchNotifications error: $e');
      return List<NotificationModel>.from(_mockNotifications);
    }
  }

  Future<void> markAllAsRead() async {
    final user = SupabaseService.currentUser;
    if (!SupabaseService.isAvailable || user == null) {
      for (var i = 0; i < _mockNotifications.length; i++) {
        final n = _mockNotifications[i];
        _mockNotifications[i] = NotificationModel(
          id: n.id,
          recipientId: n.recipientId,
          actorId: n.actorId,
          type: n.type,
          shotId: n.shotId,
          read: true,
          actor: n.actor,
          createdAt: n.createdAt,
        );
      }
      return;
    }

    try {
      await SupabaseService.client
          .from('notifications')
          .update({'read': true}).eq('recipient_id', user.id);
    } catch (e) {
      debugPrint('[NotificationsService] markAllAsRead error: $e');
    }
  }
}

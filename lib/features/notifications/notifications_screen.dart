// ═════════════════════════════════════════════════════════════════════════════
// V Shots — NotificationsScreen (Nova Design System Inbox)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/notifications_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = <NotificationModel>[];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final results = await NotificationsService.instance.fetchNotifications();
    if (mounted) {
      setState(() {
        _notifications = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    await NotificationsService.instance.markAllAsRead();
    unawaited(_loadNotifications());
  }

  List<NotificationModel> get _filteredNotifications {
    if (_selectedFilter == 'likes') {
      return _notifications
          .where((n) => n.type == NotificationType.like)
          .toList();
    }
    if (_selectedFilter == 'comments') {
      return _notifications
          .where((n) => n.type == NotificationType.comment)
          .toList();
    }
    if (_selectedFilter == 'follows') {
      return _notifications
          .where((n) => n.type == NotificationType.follow)
          .toList();
    }
    return _notifications;
  }

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return 'just now';
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textMain,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Activity'),
                  const SizedBox(width: 8),
                  _buildFilterChip('likes', 'Likes'),
                  const SizedBox(width: 8),
                  _buildFilterChip('comments', 'Comments'),
                  const SizedBox(width: 8),
                  _buildFilterChip('follows', 'Followers'),
                ],
              ),
            ),
          ),
          const Divider(color: AppColors.borderSubtle, height: 1),

          // Notifications List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryLight,
                      ),
                    ),
                  )
                : _filteredNotifications.isEmpty
                    ? const EmptyState(
                        title: 'All caught up!',
                        subtitle:
                            'When creators like, comment, or follow your shots, they will show up here.',
                        icon: Icons.notifications_none_rounded,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        color: AppColors.primaryLight,
                        backgroundColor: AppColors.surface2,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredNotifications.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final n = _filteredNotifications[index];
                            return _buildNotificationCard(n);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textMuted,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel n) {
    IconData typeIcon;
    Color iconColor;
    String actionText;

    switch (n.type) {
      case NotificationType.like:
        typeIcon = Icons.favorite_rounded;
        iconColor = AppColors.hotPink;
        actionText = 'liked your shot.';
        break;
      case NotificationType.comment:
        typeIcon = Icons.chat_bubble_rounded;
        iconColor = AppColors.accent;
        actionText = 'commented on your shot.';
        break;
      case NotificationType.follow:
        typeIcon = Icons.person_add_rounded;
        iconColor = AppColors.primaryLight;
        actionText = 'started following you.';
        break;
      case NotificationType.mention:
        typeIcon = Icons.alternate_email_rounded;
        iconColor = AppColors.warning;
        actionText = 'mentioned you.';
        break;
      case NotificationType.system:
        typeIcon = Icons.bolt_rounded;
        iconColor = AppColors.success;
        actionText = 'posted a system update.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: n.read ? AppColors.surface : AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: n.read
              ? AppColors.borderSubtle
              : AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppAvatar(
                avatarUrl: n.actor?.avatarUrl,
                name: n.actor?.fullName ?? 'Creator',
                size: 44,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 1.5),
                  ),
                  child: Icon(typeIcon, size: 12, color: iconColor),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    children: [
                      TextSpan(
                        text: n.actor?.fullName ?? 'Creator',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: actionText,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimeAgo(n.createdAt),
                  style: const TextStyle(
                    color: AppColors.textSubtle,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!n.read)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
              ),
            ),
        ],
      ),
    );
  }
}

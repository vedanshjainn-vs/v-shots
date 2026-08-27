// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Notification Preferences Model
// ═════════════════════════════════════════════════════════════════════════════

class NotificationPreferences {
  final String userId;
  final bool notificationsEnabled;
  final bool newMusicEnabled;
  final bool recommendationsEnabled;
  final bool trendingEnabled;
  final bool winbackEnabled;
  final bool updateNotificationsEnabled;
  final String? preferredTime;
  final String? timezone;
  final DateTime updatedAt;

  NotificationPreferences({
    required this.userId,
    this.notificationsEnabled = true,
    this.newMusicEnabled = true,
    this.recommendationsEnabled = true,
    this.trendingEnabled = true,
    this.winbackEnabled = true,
    this.updateNotificationsEnabled = true,
    this.preferredTime,
    this.timezone,
    required this.updatedAt,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      userId: json['user_id'] as String,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      newMusicEnabled: json['new_music_enabled'] as bool? ?? true,
<<<<<<< HEAD
      recommendationsEnabled:
          json['recommendations_enabled'] as bool? ?? true,
=======
      recommendationsEnabled: json['recommendations_enabled'] as bool? ?? true,
>>>>>>> 3f91a8f (fix: format all files + add rewarded ad button on home page)
      trendingEnabled: json['trending_enabled'] as bool? ?? true,
      winbackEnabled: json['winback_enabled'] as bool? ?? true,
      updateNotificationsEnabled:
          json['update_notifications_enabled'] as bool? ?? true,
      preferredTime: json['preferred_time'] as String?,
      timezone: json['timezone'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'notifications_enabled': notificationsEnabled,
      'new_music_enabled': newMusicEnabled,
      'recommendations_enabled': recommendationsEnabled,
      'trending_enabled': trendingEnabled,
      'winback_enabled': winbackEnabled,
      'update_notifications_enabled': updateNotificationsEnabled,
      'preferred_time': preferredTime,
      'timezone': timezone,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  NotificationPreferences copyWith({
    bool? notificationsEnabled,
    bool? newMusicEnabled,
    bool? recommendationsEnabled,
    bool? trendingEnabled,
    bool? winbackEnabled,
    bool? updateNotificationsEnabled,
    String? preferredTime,
    String? timezone,
  }) {
    return NotificationPreferences(
      userId: userId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      newMusicEnabled: newMusicEnabled ?? this.newMusicEnabled,
      recommendationsEnabled:
          recommendationsEnabled ?? this.recommendationsEnabled,
      trendingEnabled: trendingEnabled ?? this.trendingEnabled,
      winbackEnabled: winbackEnabled ?? this.winbackEnabled,
      updateNotificationsEnabled:
          updateNotificationsEnabled ?? this.updateNotificationsEnabled,
      preferredTime: preferredTime ?? this.preferredTime,
      timezone: timezone ?? this.timezone,
      updatedAt: DateTime.now(),
    );
  }
}

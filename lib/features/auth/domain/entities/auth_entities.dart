// ════════════════════════════════════════════════
// Project Lyra — Auth Entities
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_entities.freezed.dart';
part 'auth_entities.g.dart';

/// User entity — the core user profile.
@freezed
class LyraUser with _$LyraUser {
  const factory LyraUser({
    required String id,
    required String email,
    String? displayName,
    String? avatarUrl,
    String? phoneNumber,
    @Default(false) bool isEmailVerified,
    @Default(false) bool isAnonymous,
    @Default(SubscriptionTier.free) SubscriptionTier subscriptionTier,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default({}) Map<String, dynamic> metadata,
  }) = _LyraUser;

  factory LyraUser.fromJson(Map<String, dynamic> json) =>
      _$LyraUserFromJson(json);
}

/// Authentication session.
@freezed
class AuthSession with _$AuthSession {
  const factory AuthSession({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
    required String userId,
    String? provider,
    @Default({}) Map<String, dynamic> providerData,
  }) = _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);
}

/// Authentication token pair.
@freezed
class AuthToken with _$AuthToken {
  const factory AuthToken({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
    String? tokenType,
  }) = _AuthToken;

  factory AuthToken.fromJson(Map<String, dynamic> json) =>
      _$AuthTokenFromJson(json);
}

/// Subscription tier.
enum SubscriptionTier {
  free,
  premium,
  premiumFamily,
  premiumStudent,
  premiumDuo;

  bool get isPremium => this != free;
  String get displayName => switch (this) {
        free => 'Free',
        premium => 'Premium',
        premiumFamily => 'Family',
        premiumStudent => 'Student',
        premiumDuo => 'Duo',
      };
}

/// Authentication method.
enum AuthMethod {
  email,
  google,
  apple,
  phone,
  anonymous;
}

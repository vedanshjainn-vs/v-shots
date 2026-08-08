// ════════════════════════════════════════════════
// Project Lyra — Subscription Tier Enum
// ════════════════════════════════════════════════

/// User subscription levels.
enum SubscriptionTier {
  /// Free tier — ad-supported, limited skips.
  free,

  /// Premium — ad-free, offline, high quality.
  premium,

  /// Premium Family — up to 6 accounts.
  premiumFamily,

  /// Premium Student — discounted rate.
  premiumStudent,

  /// Premium Duo — 2 accounts.
  premiumDuo;

  bool get isFree => this == free;
  bool get isPremium => this != free;
  bool get isFamily => this == premiumFamily;
  bool get isStudent => this == premiumStudent;

  /// Whether the user can stream at high quality (320kbps).
  bool get canStreamHQ => isPremium;

  /// Whether the user can download for offline.
  bool get canDownload => isPremium;

  /// Whether the user gets ad-free experience.
  bool get isAdFree => isPremium;

  /// Maximum audio quality in kbps.
  int get maxBitrate => isPremium ? 320 : 128;

  String get displayName => switch (this) {
        free => 'Free',
        premium => 'Premium',
        premiumFamily => 'Family',
        premiumStudent => 'Student',
        premiumDuo => 'Duo',
      };
}

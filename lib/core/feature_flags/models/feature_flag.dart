// ════════════════════════════════════════════════
// Project Lyra — Feature Flag Model
// ════════════════════════════════════════════════
//
// Typed feature flag with support for:
// - Boolean flags (on/off)
// - Percentage rollout (10% of users)
// - Kill switches (emergency off)
// - A/B test variants
// ════════════════════════════════════════════════

/// Type of feature flag.
enum FeatureFlagType {
  /// Simple on/off toggle.
  boolean,

  /// Percentage-based rollout (0-100).
  percentage,

  /// A/B test with named variants.
  experiment,

  /// Emergency kill switch.
  killSwitch,
}

/// A feature flag configuration.
class FeatureFlag {
  const FeatureFlag({
    required this.key,
    required this.type,
    required this.defaultValue,
    this.description,
    this.rolloutPercentage = 100,
    this.variants = const {},
    this.isKillSwitchActive = false,
    this.metadata = const {},
  });

  /// Unique key for this flag (e.g., 'ai_search_enabled').
  final String key;

  /// Type of flag.
  final FeatureFlagType type;

  /// Default value when no override is set.
  final dynamic defaultValue;

  /// Human-readable description.
  final String? description;

  /// Percentage of users who see this flag (0-100).
  final int rolloutPercentage;

  /// Named variants for A/B tests.
  final Map<String, dynamic> variants;

  /// Whether the kill switch is active (forces flag off).
  final bool isKillSwitchActive;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  /// Whether this flag is a kill switch that's currently active.
  bool get isKilled => type == FeatureFlagType.killSwitch && isKillSwitchActive;

  /// Get a variant value by name.
  T? getVariant<T>(String name) => variants[name] as T?;

  Map<String, dynamic> toJson() => {
        'key': key,
        'type': type.name,
        'defaultValue': defaultValue,
        'description': description,
        'rolloutPercentage': rolloutPercentage,
        'variants': variants,
        'isKillSwitchActive': isKillSwitchActive,
        'metadata': metadata,
      };

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    return FeatureFlag(
      key: json['key'] as String,
      type: FeatureFlagType.values.byName(json['type'] as String),
      defaultValue: json['defaultValue'],
      description: json['description'] as String?,
      rolloutPercentage: json['rolloutPercentage'] as int? ?? 100,
      variants: (json['variants'] as Map<String, dynamic>?) ?? {},
      isKillSwitchActive: json['isKillSwitchActive'] as bool? ?? false,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}

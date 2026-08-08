// ════════════════════════════════════════════════
// Project Lyra — Feature Flag Service
// ════════════════════════════════════════════════
//
// Central service for evaluating feature flags.
// Supports local defaults + remote overrides.
// Percentage rollout based on user ID hash.
// ════════════════════════════════════════════════

import 'dart:convert';

import '../../logging/app_logger.dart';
import '../models/feature_flag.dart';

/// Service for evaluating feature flags.
///
/// Flags can come from:
/// - Local defaults (hardcoded)
/// - Remote config (Supabase / Firebase Remote Config)
/// - Runtime overrides (for testing)
///
/// ```dart
/// final flags = FeatureFlagService();
/// if (flags.isEnabled('ai_search_enabled')) {
///   // Show AI search.
/// }
/// final variant = flags.getExperiment('home_feed_algorithm');
/// ```
class FeatureFlagService {
  FeatureFlagService({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  /// Local flag definitions.
  final Map<String, FeatureFlag> _flags = {};

  /// Runtime overrides (for testing/debugging).
  final Map<String, dynamic> _overrides = {};

  /// Remote flag values (from server).
  final Map<String, dynamic> _remoteValues = {};

  /// User ID for percentage rollout calculation.
  String? _userId;

  // ── Initialization ───────────────────────────

  /// Register local flag definitions.
  void registerFlags(List<FeatureFlag> flags) {
    for (final flag in flags) {
      _flags[flag.key] = flag;
    }
  }

  /// Set the current user ID for percentage rollout.
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Update remote flag values (from server fetch).
  void updateRemoteValues(Map<String, dynamic> values) {
    _remoteValues.addAll(values);
    _logger.d('FeatureFlags: Updated ${values.length} remote values');
  }

  // ── Evaluation ───────────────────────────────

  /// Check if a boolean flag is enabled.
  bool isEnabled(String key) {
    // Check runtime override first.
    if (_overrides.containsKey(key)) {
      return _overrides[key] == true;
    }

    final flag = _flags[key];
    if (flag == null) {
      _logger.w('FeatureFlags: Unknown flag "$key"');
      return false;
    }

    // Kill switch check.
    if (flag.isKilled) return false;

    // Remote override.
    final remoteValue = _remoteValues[key];
    if (remoteValue != null) return remoteValue == true;

    // Percentage rollout.
    if (flag.type == FeatureFlagType.percentage) {
      return _isInRollout(key, flag.rolloutPercentage);
    }

    // Default value.
    return flag.defaultValue == true;
  }

  /// Get an experiment variant.
  String? getExperiment(String key) {
    if (_overrides.containsKey(key)) {
      return _overrides[key] as String?;
    }

    final flag = _flags[key];
    if (flag == null || flag.type != FeatureFlagType.experiment) return null;

    if (flag.isKilled) return null;

    final remoteValue = _remoteValues[key];
    if (remoteValue != null) return remoteValue as String?;

    // Select variant based on user ID hash.
    return _selectVariant(key, flag.variants.keys.toList());
  }

  /// Get a flag value with type.
  T getValue<T>(String key, T defaultValue) {
    if (_overrides.containsKey(key)) {
      return _overrides[key] as T;
    }

    final flag = _flags[key];
    if (flag == null) return defaultValue;

    if (flag.isKilled) return defaultValue;

    final remoteValue = _remoteValues[key];
    if (remoteValue != null) return remoteValue as T;

    return (flag.defaultValue as T?) ?? defaultValue;
  }

  // ── Testing Overrides ────────────────────────

  /// Override a flag value (for testing).
  void override(String key, dynamic value) {
    _overrides[key] = value;
  }

  /// Clear all overrides.
  void clearOverrides() {
    _overrides.clear();
  }

  // ── Private Helpers ──────────────────────────

  /// Check if user falls within rollout percentage.
  bool _isInRollout(String key, int percentage) {
    if (percentage >= 100) return true;
    if (percentage <= 0) return false;

    final hash = '${key}_$_userId'.hashCode.abs();
    return (hash % 100) < percentage;
  }

  /// Select an A/B test variant based on user ID hash.
  String? _selectVariant(String key, List<String> variants) {
    if (variants.isEmpty) return null;

    final hash = '${key}_ab_$_userId'.hashCode.abs();
    return variants[hash % variants.length];
  }
}

/// Well-known feature flag keys.
abstract final class FeatureFlagKeys {
  // ── AI Features ──────────────────────────────
  static const String aiSearchEnabled = 'ai_search_enabled';
  static const String aiDJEnabled = 'ai_dj_enabled';
  static const String aiRecommendationsEnabled = 'ai_recommendations_enabled';

  // ── Player ───────────────────────────────────
  static const String lyricsEnabled = 'lyrics_enabled';
  static const String crossfadeEnabled = 'crossfade_enabled';
  static const String gaplessPlayback = 'gapless_playback';

  // ── Social ───────────────────────────────────
  static const String socialFeaturesEnabled = 'social_features_enabled';
  static const String collaborativePlaylists = 'collaborative_playlists';

  // ── Premium ──────────────────────────────────
  static const String premiumUpsellEnabled = 'premium_upsell_enabled';
  static const String familyPlanEnabled = 'family_plan_enabled';

  // ── Content ──────────────────────────────────
  static const String podcastsEnabled = 'podcasts_enabled';
  static const String audiobooksEnabled = 'audiobooks_enabled';
  static const String musicVideosEnabled = 'music_videos_enabled';

  // ── Kill Switches ────────────────────────────
  static const String streamingKillSwitch = 'streaming_kill_switch';
  static const String downloadsKillSwitch = 'downloads_kill_switch';

  // ── Experiments ──────────────────────────────
  static const String homeFeedAlgorithm = 'home_feed_algorithm';
  static const String searchAlgorithm = 'search_algorithm';
  static const String playerUITheme = 'player_ui_theme';
}

// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Remote feature flags (Supabase-backed, safe defaults)
// ═════════════════════════════════════════════════════════════════════════════
//
// Runtime gates. A missing/unreachable flag NEVER enables JioSaavn or social
// UI, and NEVER blocks app startup. Values come from RemoteConfigService
// (fetched + TTL-cached). Tests inject overrides without I/O.

import 'package:flutter/foundation.dart';

import 'remote_config_service.dart';

/// Playback-only slice so PlaybackRouter tests stay free of singletons.
class PlaybackPolicy {
  const PlaybackPolicy({
    this.jiosaavnWebPlayback = false,
    this.jiosaavnSearchFallback = false,
    this.youtubeWebPlayback = true,
    this.jiosaavnExactUrls = true,
  });

  final bool jiosaavnWebPlayback;
  final bool jiosaavnSearchFallback;

  /// Master switch for YouTube webpage playback. Defaults to ON; turning it
  /// OFF in Supabase makes the router report YouTube targets as unavailable.
  final bool youtubeWebPlayback;

  /// Whether exact JioSaavn permalinks from CMS items are honored. When OFF
  /// the router skips permalinks (search fallback still applies if enabled).
  final bool jiosaavnExactUrls;
}

class RemoteFeatureFlags {
  RemoteFeatureFlags._();
  static final RemoteFeatureFlags instance = RemoteFeatureFlags._();

  /// Safe defaults when Supabase has not returned a value.
  static const Map<String, bool> defaults = {
    'enable_remote_home': true,
    'enable_jiosaavn_web_playback': false,
    'enable_jiosaavn_search_fallback': false,
    'enable_jiosaavn_exact_urls': true,
    'enable_youtube_web_playback': true,
    'enable_discovery_remote_categories': false,
    'enable_social': false,
  };

  Map<String, bool>? _override;

  /// Test-only: replace the live map. Pass null to clear.
  @visibleForTesting
  void debugOverride(Map<String, bool>? flags) {
    _override = flags;
  }

  bool value(String key, {required bool defaultValue}) {
    final override = _override;
    if (override != null) {
      return override[key] ?? defaultValue;
    }
    final stored = RemoteConfigService.instance.featureFlags[key];
    if (stored == null) return defaultValue;
    return stored;
  }

  bool get enableRemoteHome => value('enable_remote_home', defaultValue: true);

  bool get enableJioSaavnWebPlayback =>
      value('enable_jiosaavn_web_playback', defaultValue: false);

  bool get enableJioSaavnSearchFallback =>
      value('enable_jiosaavn_search_fallback', defaultValue: false);

  bool get enableJioSaavnExactUrls =>
      value('enable_jiosaavn_exact_urls', defaultValue: true);

  bool get enableYouTubeWebPlayback =>
      value('enable_youtube_web_playback', defaultValue: true);

  bool get enableDiscoveryRemoteCategories =>
      value('enable_discovery_remote_categories', defaultValue: false);

  bool get enableSocial => value('enable_social', defaultValue: false);

  PlaybackPolicy get playbackPolicy => PlaybackPolicy(
        jiosaavnWebPlayback: enableJioSaavnWebPlayback,
        jiosaavnSearchFallback: enableJioSaavnSearchFallback,
        youtubeWebPlayback: enableYouTubeWebPlayback,
        jiosaavnExactUrls: enableJioSaavnExactUrls,
      );
}

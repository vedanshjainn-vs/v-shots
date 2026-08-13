// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — music_core / playback resolver (vision §22, §23, §48)
//
// Deterministically determines whether a track is playable, and via which
// authorized source, given the user's authentication/region and each provider's
// capability profile. It NEVER claims a source is playable unless the provider
// actually confirms availability, and it NEVER fabricates an unauthorized
// playback path. If no eligible source exists, it reports "unavailable".
// ═════════════════════════════════════════════════════════════════════════

import 'provider_capabilities.dart';

/// The resolved playback outcome for a track.
class PlaybackResolution {
  const PlaybackResolution({
    required this.playable,
    this.source,
    this.reason = '',
  });

  final bool playable;
  final String? source; // e.g. 'youtube_iframe', 'vshots_licensed_cdn'
  final String reason;

  static const unavailable =
      PlaybackResolution(playable: false, reason: 'Playback unavailable');
}

class PlaybackResolver {
  const PlaybackResolver({required this.matrix});

  final ProviderCapabilityMatrix matrix;

  /// Resolves the best authorized playback source for a track.
  ///
  /// [eligibleProviderIds] is the ordered list of providers that have already
  /// confirmed this track is available to play for this user/region (callers
  /// must verify availability; the resolver does not invent it).
  PlaybackResolution resolve({
    required List<String> eligibleProviderIds,
    bool userAuthenticated = false,
    bool regionAllowed = true,
  }) {
    if (!regionAllowed) {
      return const PlaybackResolution(
        playable: false,
        reason: 'Playback unavailable in your region',
      );
    }

    // Priority order (vision §22): own licensed catalog, then authorized
    // providers, then official YouTube IFrame.
    const priority = ['vshots_licensed', 'spotify', 'applemusic', 'youtube'];
    for (final id in priority) {
      if (!eligibleProviderIds.contains(id)) continue;
      final profile = matrix.byId(id);
      if (profile == null) continue;
      // An auth-required provider with no authenticated user -> clear reason
      // (more informative than a generic "not available").
      if (profile.requiresAuthentication && !userAuthenticated) {
        return PlaybackResolution(
          playable: false,
          source: id,
          reason: 'Sign in to play on ${profile.displayName}',
        );
      }
      if (!profile.allowsFullPlayback) continue;
      final sourceName = switch (id) {
        'vshots_licensed' => 'vshots_licensed_cdn',
        'youtube' => 'youtube_iframe',
        _ => id,
      };
      return PlaybackResolution(
        playable: true,
        source: sourceName,
        reason: 'Play via ${profile.displayName}',
      );
    }

    // A provider is available but does not allow full playback -> not playable
    // here (e.g. Spotify preview-only without premium).
    for (final id in eligibleProviderIds) {
      final profile = matrix.byId(id);
      if (profile != null && !profile.allowsFullPlayback) {
        return PlaybackResolution(
          playable: false,
          source: id,
          reason: '${profile.displayName} playback not available',
        );
      }
    }

    return PlaybackResolution.unavailable;
  }
}

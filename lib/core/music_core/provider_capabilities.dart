// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — music_core / provider capability matrix (vision §3, §47)
//
// A capability matrix describing what each music provider may legally do.
// V SHOTS is provider-agnostic: external platforms provide capabilities;
// V SHOTS owns the experience. This file is declarative/configuration-only —
// it does NOT contain any provider credentials or scraping logic.
// ═════════════════════════════════════════════════════════════════════════

/// A capability a music provider may support. Kept aligned with the existing
/// `ProviderCapability` in core/providers/music_provider.dart, but extended for
/// the provider-agnostic matrix.
enum ProviderCapability2 {
  search,
  catalogMetadata,
  artistMetadata,
  albumMetadata,
  playlistMetadata,
  artwork,
  lyricsIfLicensed,
  previewIfAllowed,
  fullPlayback,
  backgroundPlayback,
  authenticatedPlayback,
}

/// One provider's declared capability set + compliance constraints.
class ProviderCapabilityProfile {
  const ProviderCapabilityProfile({
    required this.providerId,
    required this.displayName,
    required this.capabilities,
    this.allowsFullPlayback = false,
    this.allowsBackgroundPlayback = false,
    this.requiresAuthentication = false,
    this.regionRestricted = false,
    this.subscriptionRestricted = false,
  });

  final String providerId;
  final String displayName;
  final Set<ProviderCapability2> capabilities;
  final bool allowsFullPlayback;
  final bool allowsBackgroundPlayback;
  final bool requiresAuthentication;
  final bool regionRestricted;
  final bool subscriptionRestricted;

  bool supports(ProviderCapability2 c) => capabilities.contains(c);
}

/// The capability profiles V SHOTS currently recognises. YouTube is the only
/// wired provider today; Spotify/Apple/own-catalog are declared as future slots
/// (NOT implemented — no credentials/backend exist).
class ProviderCapabilityMatrix {
  const ProviderCapabilityMatrix(this.profiles);

  final List<ProviderCapabilityProfile> profiles;

  ProviderCapabilityProfile? byId(String id) {
    for (final p in profiles) {
      if (p.providerId == id) return p;
    }
    return null;
  }

  /// The default matrix as built from the configured provider list.
  static const ProviderCapabilityMatrix youtubeOnly = ProviderCapabilityMatrix([
    ProviderCapabilityProfile(
      providerId: 'youtube',
      displayName: 'YouTube',
      capabilities: {
        ProviderCapability2.search,
        ProviderCapability2.catalogMetadata,
        ProviderCapability2.artistMetadata,
        ProviderCapability2.artwork,
        ProviderCapability2.fullPlayback,
      },
      allowsFullPlayback: true, // via official YouTube IFrame only
      allowsBackgroundPlayback: false,
      regionRestricted: false,
      subscriptionRestricted: false,
    ),
    // Future provider slots — NOT wired, no credentials.
    ProviderCapabilityProfile(
      providerId: 'spotify',
      displayName: 'Spotify',
      capabilities: {
        ProviderCapability2.search,
        ProviderCapability2.catalogMetadata,
        ProviderCapability2.artistMetadata,
        ProviderCapability2.albumMetadata,
        ProviderCapability2.playlistMetadata,
        ProviderCapability2.artwork,
        ProviderCapability2.previewIfAllowed,
      },
      allowsFullPlayback:
          false, // requires premium + Web API auth; not configured
      requiresAuthentication: true,
      subscriptionRestricted: true,
    ),
    ProviderCapabilityProfile(
      providerId: 'applemusic',
      displayName: 'Apple Music',
      capabilities: {
        ProviderCapability2.search,
        ProviderCapability2.catalogMetadata,
        ProviderCapability2.artistMetadata,
        ProviderCapability2.albumMetadata,
        ProviderCapability2.artwork,
        ProviderCapability2.previewIfAllowed,
      },
      allowsFullPlayback: false,
      requiresAuthentication: true,
      subscriptionRestricted: true,
    ),
    ProviderCapabilityProfile(
      providerId: 'vshots_licensed',
      displayName: 'V SHOTS Licensed Catalog',
      capabilities: {
        ProviderCapability2.search,
        ProviderCapability2.catalogMetadata,
        ProviderCapability2.artistMetadata,
        ProviderCapability2.albumMetadata,
        ProviderCapability2.playlistMetadata,
        ProviderCapability2.artwork,
        ProviderCapability2.lyricsIfLicensed,
        ProviderCapability2.fullPlayback,
        ProviderCapability2.backgroundPlayback,
      },
      allowsFullPlayback: true, // future own-CDN catalog (vision §49)
      allowsBackgroundPlayback: true,
    ),
  ]);
}

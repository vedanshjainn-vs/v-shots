// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — Configured Playlist Source (Verified IDs Only)
//
// channelSections.list is the PRIMARY playlist-discovery path (see
// PlaylistContentService). However, the auto-generated YouTube Music channel
// may not expose every section via the public API. As a guaranteed, NON-guessed
// fallback we also read real playlist ids from this file.
//
// RULES (binding):
//   • NEVER guess / invent a playlist id here. Only paste the real id copied
//     from a youtube.com/playlist?list=... URL on the official YouTube Music
//     channel (the token looks like PL..., OL..., or RD...).
//   • Each entry's `id` must be a REAL playlist id. If you are not sure it is
//     real, do not add it — an empty list is better than a fabricated one.
//
// Fill the list below with entries like:
//   ConfiguredPlaylist(id: 'PL9tY0BWXOZFu...', title: 'Trending Now'),
//
// The next Home refresh automatically builds a section per entry.
// ═════════════════════════════════════════════════════════════════════════

/// A playlist id + display title supplied explicitly (user-verified).
class ConfiguredPlaylist {
  const ConfiguredPlaylist({
    required this.id,
    required this.title,
    this.category = 'More From YouTube Music',
  });

  final String id;
  final String title;
  final String category;
}

/// Real, user-verified playlist ids from the official YouTube Music channel.
///
/// Intentionally EMPTY until the user pastes real `list=...` ids. V Shots
/// never fabricates playlist ids, so an empty source simply means Home falls
/// back to channelSections auto-discovery.
const List<ConfiguredPlaylist> kConfiguredPlaylists = [];

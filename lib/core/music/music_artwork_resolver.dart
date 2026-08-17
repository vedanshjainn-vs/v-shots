// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music artwork resolver
// ═════════════════════════════════════════════════════════════════════════════
//
// Single source of truth for choosing a music card's artwork, in priority
// order: album artwork → music artwork → structured music artwork → official
// video thumbnail. Never fabricates a URL; returns null when nothing is
// available (callers show a neutral placeholder).
// ═════════════════════════════════════════════════════════════════════════════

class MusicArtworkResolver {
  const MusicArtworkResolver();

  String? resolve({
    String? albumArtwork,
    String? musicArtwork,
    String? structuredArtwork,
    String? videoThumbnail,
  }) {
    return _firstNonEmpty([
      albumArtwork,
      musicArtwork,
      structuredArtwork,
      videoThumbnail,
    ]);
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}

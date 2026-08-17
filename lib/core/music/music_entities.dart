// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music entities (canonical song / artist / album identity)
// ═════════════════════════════════════════════════════════════════════════════
//
// MUSIC INTELLIGENCE V3. The core idea: "song", "artist", "album" and
// "video" are SEPARATE concepts — a YouTube videoId is only a source id,
// never the canonical song identity. This file owns:
//   • MusicVariant (meaningful versions that must stay distinct)
//   • normalizeMusicTitle() (strips presentation noise, keeps variants)
//   • canonicalSongId() (artist + title + variant — never the videoId)
//   • the typed MusicSongEntity / MusicArtistEntity / MusicAlbumEntity
// ═════════════════════════════════════════════════════════════════════════════

/// Meaningful variants of the SAME song — these are separate recommendations,
/// NOT duplicates (a remix is a different release than the original).
enum MusicVariant {
  original,
  remix,
  acoustic,
  live,
  unplugged,
  instrumental,
  extended,
}

/// Representation/presentation markers that do NOT change the song identity.
const List<String> _representationMarkers = [
  'official video',
  'official music video',
  'official audio',
  'official lyric video',
  'lyric video',
  'lyrics video',
  'lyrics',
  'lyrical',
  'full song',
  'full hd',
  'fullhd',
  ' hd',
  ' 4k',
  ' 1080p',
  'visualizer',
  'visualiser',
  'audio',
  'video song',
];

/// Normalizes a raw title into the canonical song title: removes ONLY
/// representation markers ("Official Video/Audio", "Lyrics", "HD/4K",
/// "Visualizer") and keeps meaningful variants (Remix/Acoustic/Live/
/// Unplugged/Instrumental/Extended).
String normalizeMusicTitle(String value) {
  var title = value.trim();
  // Remove bracketed markers like "(Official Video)", "[Official Audio]".
  title = title.replaceAll(
    RegExp(
      r'[\(\[][^\)\]]*(official|lyrics?|audio|video|hd|4k|visuali[sz]er)[^\)\]]*[\)\]]',
      caseSensitive: false,
    ),
    ' ',
  );
  // Remove representation markers ANYWHERE (they are noise, unlike
  // meaningful variants which are deliberately NOT in the marker list).
  for (final marker in _representationMarkers) {
    title = title.replaceAll(
      RegExp(RegExp.escape(marker), caseSensitive: false),
      ' ',
    );
  }
  // Collapse separators/whitespace left behind.
  title = title.replaceAll(RegExp(r'[\|\-–—]'), ' ');
  title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  return title.isEmpty ? value.trim() : title;
}

/// Canonical song identity — artist + normalized title + variant. The YouTube
/// videoId is NEVER used here (it is only the sourceVideoId elsewhere).
String canonicalSongId({
  required String title,
  String? artistId,
  String? artistName,
  MusicVariant variant = MusicVariant.original,
}) {
  final normalizedArtist = _normalizeIdentity(
    artistId ?? artistName ?? 'unknown-artist',
  );
  final normalizedTitle = _normalizeIdentity(normalizeMusicTitle(title));
  return '$normalizedArtist|$normalizedTitle|${variant.name}';
}

String _normalizeIdentity(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Detect the meaningful variant from a title (order matters: the most
/// specific markers win).
MusicVariant detectMusicVariant(String title) {
  final t = title.toLowerCase();
  if (t.contains('instrumental')) return MusicVariant.instrumental;
  if (t.contains('acoustic')) return MusicVariant.acoustic;
  if (t.contains('unplugged')) return MusicVariant.unplugged;
  if (t.contains('extended')) return MusicVariant.extended;
  if (RegExp(r'\blive\b').hasMatch(t)) return MusicVariant.live;
  if (t.contains('remix')) return MusicVariant.remix;
  return MusicVariant.original;
}

/// A canonical song entity (independent of any single video/upload).
class MusicSongEntity {
  const MusicSongEntity({
    required this.id,
    required this.title,
    this.artistId,
    this.artistName,
    this.albumId,
    this.albumName,
    this.artworkUrl,
    this.durationSeconds,
    this.releaseDate,
    this.language,
    this.region,
    this.genre,
    this.mood,
    this.variant = MusicVariant.original,
    this.official = false,
  });

  final String id;
  final String title;
  final String? artistId;
  final String? artistName;
  final String? albumId;
  final String? albumName;
  final String? artworkUrl;
  final int? durationSeconds;
  final DateTime? releaseDate;
  final String? language;
  final String? region;
  final String? genre;
  final String? mood;
  final MusicVariant variant;
  final bool official;
}

/// A canonical artist entity (channel is the SOURCE, artist is the identity).
class MusicArtistEntity {
  const MusicArtistEntity({
    required this.id,
    required this.name,
    this.artworkUrl,
    this.verified = false,
  });

  final String id;
  final String name;
  final String? artworkUrl;
  final bool verified;
}

/// A canonical album entity (only when real album metadata exists).
class MusicAlbumEntity {
  const MusicAlbumEntity({
    required this.id,
    required this.title,
    this.artistId,
    this.artistName,
    this.artworkUrl,
    this.releaseDate,
  });

  final String id;
  final String title;
  final String? artistId;
  final String? artistName;
  final String? artworkUrl;
  final DateTime? releaseDate;
}

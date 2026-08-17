// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music entity resolver
// ═════════════════════════════════════════════════════════════════════════════
//
// Turns a raw ProviderTrack (a YouTube upload) into a resolved MUSIC identity:
// song / artist / album / variant / officiality / artwork / canonical id.
//
// NEVER does "artist = channelName" blindly: the channel name is only used as
// the artist FALLBACK; a real artistId (channelId) is preferred when present.
// ═════════════════════════════════════════════════════════════════════════════

import '../providers/provider_models.dart';
import '../recommendation/genre_classifier.dart';
import 'music_artwork_resolver.dart';
import 'music_entities.dart';

/// The resolved identity of a track: canonical song + artist (+ album when
/// real metadata exists) + variant + officiality + chosen artwork.
class MusicEntityResolution {
  const MusicEntityResolution({
    required this.song,
    required this.artist,
    required this.variant,
    required this.official,
    required this.canonicalId,
    this.album,
    this.artworkUrl,
    this.language,
    this.genre,
    this.mood,
  });

  final MusicSongEntity song;
  final MusicArtistEntity artist;
  final MusicAlbumEntity? album;
  final MusicVariant variant;
  final bool official;
  final String canonicalId;
  final String? artworkUrl;
  final String? language;
  final String? genre;
  final String? mood;
}

class MusicEntityResolver {
  const MusicEntityResolver({this.artwork = const MusicArtworkResolver()});

  final MusicArtworkResolver artwork;

  /// Resolves a raw track into its canonical music identity. Consumes
  /// ProviderTrack without changing playback semantics.
  MusicEntityResolution resolveTrack(ProviderTrack track) {
    final normalizedTitle = normalizeMusicTitle(track.title);
    final variant = detectMusicVariant(track.title);
    final canonicalId = canonicalSongId(
      title: track.title,
      artistId: track.channelId,
      artistName: track.artist,
      variant: variant,
    );
    final genres = GenreClassifier.instance.classify(
      title: track.title,
      artist: track.artist,
    );

    final song = MusicSongEntity(
      id: canonicalId,
      title: normalizedTitle,
      artistId: track.channelId,
      artistName: track.artist.isEmpty ? null : track.artist,
      artworkUrl: track.artworkUrl.isEmpty ? null : track.artworkUrl,
      durationSeconds: track.durationSeconds,
      variant: variant,
      official: track.isOfficial,
      genre: genres.isEmpty ? null : genres.first,
    );

    final artist = MusicArtistEntity(
      id: track.channelId ?? 'artist:${_identity(track.artist)}',
      name: track.artist.isEmpty ? 'Unknown Artist' : track.artist,
      verified: track.isOfficial,
      artworkUrl: track.artworkUrl.isEmpty ? null : track.artworkUrl,
    );

    return MusicEntityResolution(
      song: song,
      artist: artist,
      album: null, // no real album metadata in the current pipeline (honest)
      variant: variant,
      official: track.isOfficial,
      canonicalId: canonicalId,
      artworkUrl: artwork.resolve(videoThumbnail: track.artworkUrl),
      language: detectLanguage(track.title, track.artist),
      genre: genres.isEmpty ? null : genres.first,
    );
  }

  static String _identity(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Lightweight language heuristic from title/artist text (real text signals,
/// not fabricated). Returns null when no language is confidently detected.
String? detectLanguage(String title, String artist) {
  final haystack = '${title.toLowerCase()} ${artist.toLowerCase()}';
  const languages = {
    'punjabi': 'punjabi',
    'hindi': 'hindi',
    'bollywood': 'hindi',
    'tamil': 'tamil',
    'telugu': 'telugu',
    'bengali': 'bengali',
    'marathi': 'marathi',
    'gujarati': 'gujarati',
    'bhojpuri': 'bhojpuri',
    'haryanvi': 'haryanvi',
    'malayalam': 'malayalam',
    'kannada': 'kannada',
    'english': 'english',
    'k-pop': 'korean',
    'kpop': 'korean',
  };
  for (final entry in languages.entries) {
    if (haystack.contains(entry.key)) return entry.value;
  }
  return null;
}

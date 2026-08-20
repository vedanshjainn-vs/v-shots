// ═════════════════════════════════════════════════════════════════════════════
// V Shots — JioSaavn Web Playback Provider
// ═════════════════════════════════════════════════════════════════════════════
//
// Resolves JioSaavn song URLs for web playback in the V Shots browser.
// Opens the official JioSaavn webpage — does NOT extract audio streams.
//
// LEGAL BOUNDARY:
// - Opens official JioSaavn webpage only
// - Does NOT download/extract/proxy audio
// - Does NOT bypass DRM or ads
// - Does NOT access CDN/media URLs
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result of a JioSaavn URL resolution
class JioSaavnResolvedSong {
  const JioSaavnResolvedSong({
    required this.webUrl,
    required this.title,
    required this.artist,
    this.album,
    this.providerSongId,
  });

  final String webUrl;
  final String title;
  final String artist;
  final String? album;
  final String? providerSongId;
}

/// Resolves JioSaavn song URLs for web playback
class JioSaavnWebPlaybackProvider {
  JioSaavnWebPlaybackProvider._();
  static final JioSaavnWebPlaybackProvider instance = JioSaavnWebPlaybackProvider._();

  static const String _baseUrl = 'https://www.jiosaavn.com';

  /// Resolve a JioSaavn song URL from a V Shots track map
  /// Returns the official JioSaavn webpage URL for playback
  Future<JioSaavnResolvedSong?> resolveFromTrack(Map<String, dynamic> track) async {
    final title = (track['title'] as String?) ?? '';
    final artist = (track['artist'] as String?) ?? '';
    final album = (track['album'] as String?) ?? '';

    if (title.isEmpty) return null;

    // Strategy 1: If we have a JioSaavn provider ID, construct URL directly
    final providerId = track['jiosaavn_id'] as String?;
    if (providerId != null && providerId.isNotEmpty) {
      return JioSaavnResolvedSong(
        webUrl: '$_baseUrl/song/$providerId',
        title: title,
        artist: artist,
        album: album,
        providerSongId: providerId,
      );
    }

    // Strategy 2: Search JioSaavn for the song
    final resolved = await _searchJioSaavn(title, artist);
    if (resolved != null) return resolved;

    // Strategy 3: Construct a search URL as fallback
    final searchQuery = Uri.encodeComponent('$title $artist');
    return JioSaavnResolvedSong(
      webUrl: '$_baseUrl/search/$searchQuery',
      title: title,
      artist: artist,
      album: album,
    );
  }

  /// Search JioSaavn API for a song and return its webpage URL
  Future<JioSaavnResolvedSong?> _searchJioSaavn(String title, String artist) async {
    try {
      final query = Uri.encodeComponent('$title $artist');
      final url = 'https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=query&_marker=0&cc=in&includeMetaTags=1&query=$query';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      
      // Parse songs from response
      final songs = data['songs']?['data'] as List?;
      if (songs == null || songs.isEmpty) return null;

      // Find best match
      for (final song in songs) {
        final songTitle = (song['title'] as String?)?.toLowerCase() ?? '';
        final songArtist = (song['description'] as String?)?.toLowerCase() ?? '';
        final songId = song['id'] as String?;
        final songUrl = song['url'] as String?;

        if (songId == null) continue;

        // Check if title matches
        if (_fuzzyMatch(songTitle, title.toLowerCase()) &&
            _fuzzyMatch(songArtist, artist.toLowerCase())) {
          return JioSaavnResolvedSong(
            webUrl: songUrl ?? '$_baseUrl/song/$songId',
            title: song['title'] as String? ?? title,
            artist: song['description'] as String? ?? artist,
            providerSongId: songId,
          );
        }
      }

      // If no exact match, return first result
      final firstSong = songs.first;
      final songId = firstSong['id'] as String?;
      final songUrl = firstSong['url'] as String?;
      
      if (songId != null) {
        return JioSaavnResolvedSong(
          webUrl: songUrl ?? '$_baseUrl/song/$songId',
          title: firstSong['title'] as String? ?? title,
          artist: firstSong['description'] as String? ?? artist,
          providerSongId: songId,
        );
      }

      return null;
    } catch (e) {
      // Search failed — will use fallback URL
      return null;
    }
  }

  /// Simple fuzzy string matching
  bool _fuzzyMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    // Exact match
    if (a == b) return true;
    // Contains match
    if (a.contains(b) || b.contains(a)) return true;
    // Remove common words and try again
    final cleanA = a.replaceAll(RegExp(r'\b(the|a|an|feat|ft|remix|live)\b'), '').trim();
    final cleanB = b.replaceAll(RegExp(r'\b(the|a|an|feat|ft|remix|live)\b'), '').trim();
    return cleanA == cleanB || cleanA.contains(cleanB) || cleanB.contains(cleanA);
  }
}

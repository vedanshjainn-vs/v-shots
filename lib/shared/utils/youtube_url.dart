// ═════════════════════════════════════════════════════════════════════════════
// V Shots — YouTube URL normalization (pure, reusable)
// ═════════════════════════════════════════════════════════════════════════════
//
// Normalizes supported YouTube URLs safely and builds canonical watch URLs.
// Used by the Discovery in-app browser to convert a Discovery item's videoId
// into the official YouTube watch page it loads. Pure functions — no network,
// no platform — so they are fully unit-testable and reusable elsewhere later.
// ═════════════════════════════════════════════════════════════════════════════

/// Extracts the 11-character video id from a YouTube URL, or returns the input
/// itself when it is already a bare video id. Returns null for unsupported
/// URLs. Supported forms:
///   - https://www.youtube.com/watch?v=ID  (+ query params)
///   - https://youtube.com/watch?v=ID / https://m.youtube.com/watch?v=ID
///   - https://youtu.be/ID
///   - https://www.youtube.com/embed/ID | /shorts/ID | /live/ID | /v/ID
String? extractYoutubeVideoId(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  // Already a bare video id.
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(trimmed)) return trimmed;

  Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    return null;
  }

  final host = uri.host.toLowerCase();
  final isYoutubeHost = host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtu.be' ||
      host.endsWith('.youtu.be');
  if (!isYoutubeHost) return null;

  if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
    final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    return (seg != null && seg.length == 11) ? seg : null;
  }

  if (uri.path == '/watch') {
    final id = uri.queryParameters['v'];
    return (id != null && id.isNotEmpty) ? id : null;
  }

  final segments = uri.pathSegments;
  if (segments.length >= 2) {
    final kind = segments[0];
    if (kind == 'embed' || kind == 'shorts' || kind == 'live' || kind == 'v') {
      return segments[1];
    }
  }
  return null;
}

/// Canonical YouTube watch URL for a video id.
String youtubeWatchUrl(String videoId) =>
    'https://www.youtube.com/watch?v=$videoId';

/// True when [url] is a supported YouTube URL that yields a video id.
bool isSupportedYoutubeUrl(String url) => extractYoutubeVideoId(url) != null;

/// Playlist id from a bare `PL…` / `UU…` token or a watch/playlist URL.
String? extractYoutubePlaylistId(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  if (RegExp(r'^(PL|UU|LL|FL|RD|OL)[A-Za-z0-9_-]+$').hasMatch(trimmed)) {
    return trimmed;
  }
  try {
    final uri = Uri.parse(trimmed);
    final host = uri.host.toLowerCase();
    final isYoutubeHost = host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtu.be';
    if (!isYoutubeHost) return null;
    final list = uri.queryParameters['list'];
    if (list != null && list.isNotEmpty) return list;
  } catch (_) {}
  return null;
}

/// Channel id (`UC…`) from a bare id or `/channel/UC…` URL.
/// `@handles` are not ids — callers should treat those as search queries.
String? extractYoutubeChannelId(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  if (RegExp(r'^UC[A-Za-z0-9_-]{22}$').hasMatch(trimmed)) return trimmed;
  try {
    final uri = Uri.parse(trimmed);
    final host = uri.host.toLowerCase();
    final isYoutubeHost =
        host == 'youtube.com' || host.endsWith('.youtube.com');
    if (!isYoutubeHost) return null;
    final segs = uri.pathSegments;
    if (segs.length >= 2 && segs[0] == 'channel') {
      final id = segs[1];
      return id.startsWith('UC') ? id : null;
    }
  } catch (_) {}
  return null;
}

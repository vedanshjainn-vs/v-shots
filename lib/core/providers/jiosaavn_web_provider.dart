// ═════════════════════════════════════════════════════════════════════════════
// V Shots — JioSaavn Web Provider (official webpage URL only)
// ═════════════════════════════════════════════════════════════════════════════
//
// Resolves ONLY:
//   1. an admin-provided HTTPS JioSaavn song permalink
//   2. an official JioSaavn search URL (when fallback is enabled)
//
// No unofficial APIs, no media/CDN/download URLs, no opaque-id generation.

class JioSaavnUrlKind {
  static const none = 'none';
  static const permalink = 'permalink';
  static const search = 'search';
  static const invalid = 'invalid';
}

class JioSaavnUrlCheck {
  const JioSaavnUrlCheck({required this.kind, required this.reason});

  final String kind;
  final String reason;

  bool get isPermalink => kind == JioSaavnUrlKind.permalink;
  bool get isSearch => kind == JioSaavnUrlKind.search;
  bool get isAllowedPage => isPermalink || isSearch;
}

class JioSaavnWebProvider {
  JioSaavnWebProvider._();
  static final JioSaavnWebProvider instance = JioSaavnWebProvider._();

  static const Set<String> pageHosts = {'jiosaavn.com', 'www.jiosaavn.com'};

  static const List<String> _mediaExt = [
    '.mp3',
    '.m4a',
    '.m3u8',
    '.mp4',
    '.mpd',
    '.aac',
  ];

  static const List<String> _deniedHostParts = [
    'api.',
    'cdn',
    'stream',
    'download',
    'media',
  ];

  /// Inspect a candidate URL. Never hits the network.
  static JioSaavnUrlCheck inspect(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return const JioSaavnUrlCheck(
        kind: JioSaavnUrlKind.none,
        reason: 'empty',
      );
    }
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('javascript:') ||
        lower.startsWith('data:') ||
        lower.startsWith('file:') ||
        lower.startsWith('intent:')) {
      return const JioSaavnUrlCheck(
        kind: JioSaavnUrlKind.invalid,
        reason: 'disallowed scheme',
      );
    }
    if (!lower.startsWith('https://')) {
      return const JioSaavnUrlCheck(
        kind: JioSaavnUrlKind.invalid,
        reason: 'https required',
      );
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme != 'https') {
      return const JioSaavnUrlCheck(
        kind: JioSaavnUrlKind.invalid,
        reason: 'unparseable',
      );
    }
    final host = uri.host.toLowerCase();
    if (host.isEmpty) {
      return const JioSaavnUrlCheck(
        kind: JioSaavnUrlKind.invalid,
        reason: 'missing host',
      );
    }
    if (host == 'saavn.me' || host.endsWith('.saavn.me')) {
      return const JioSaavnUrlCheck(
        kind: JioSaavnUrlKind.invalid,
        reason: 'third-party domain',
      );
    }
    if (host == 'api.jiosaavn.com' || host.endsWith('.api.jiosaavn.com')) {
      return const JioSaavnUrlCheck(
        kind: JioSaavnUrlKind.invalid,
        reason: 'api endpoint',
      );
    }
    if (!pageHosts.contains(host)) {
      return const JioSaavnUrlCheck(
        kind: JioSaavnUrlKind.invalid,
        reason: 'unknown domain',
      );
    }
    for (final part in _deniedHostParts) {
      if (host.contains(part)) {
        return const JioSaavnUrlCheck(
          kind: JioSaavnUrlKind.invalid,
          reason: 'media/cdn host',
        );
      }
    }
    final path = uri.path.toLowerCase();
    for (final ext in _mediaExt) {
      if (path.endsWith(ext) || lower.contains(ext)) {
        return const JioSaavnUrlCheck(
          kind: JioSaavnUrlKind.invalid,
          reason: 'media url',
        );
      }
    }
    if (path.startsWith('/song/') && uri.pathSegments.length >= 3) {
      return const JioSaavnUrlCheck(
        kind: JioSaavnUrlKind.permalink,
        reason: 'permalink',
      );
    }
    if (path.startsWith('/search/songs/')) {
      return const JioSaavnUrlCheck(
        kind: JioSaavnUrlKind.search,
        reason: 'search',
      );
    }
    return const JioSaavnUrlCheck(
      kind: JioSaavnUrlKind.invalid,
      reason: 'not a song permalink or search url',
    );
  }

  static bool isValidPermalink(String url) => inspect(url).isPermalink;

  static bool isValidSearchUrl(String url) => inspect(url).isSearch;

  /// True for an official song permalink OR an official search URL.
  static bool isValidJioSaavnUrl(String url) => inspect(url).isAllowedPage;

  static String buildSearchUrl({required String title, String artist = ''}) {
    final query = _buildSearchQuery(title, artist);
    if (query.isEmpty) return '';
    final encodedQuery = Uri.encodeComponent(query);
    return 'https://www.jiosaavn.com/search/songs/$encodedQuery';
  }

  Future<String?> resolveWebUrl({
    required String title,
    String artist = '',
    String? permalink,
    bool allowSearchFallback = true,
  }) async {
    if (permalink != null && permalink.isNotEmpty) {
      if (isValidPermalink(permalink)) return permalink;
      if (isValidSearchUrl(permalink) && allowSearchFallback) {
        return permalink;
      }
    }
    if (!allowSearchFallback) return null;
    final url = buildSearchUrl(title: title, artist: artist);
    return url.isEmpty ? null : url;
  }

  static String _buildSearchQuery(String title, String artist) {
    final parts = <String>[];
    if (title.trim().isNotEmpty) parts.add(title.trim());
    if (artist.trim().isNotEmpty) parts.add(artist.trim());
    return parts.join(' ');
  }
}

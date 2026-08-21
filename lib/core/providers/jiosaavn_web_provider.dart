// ═════════════════════════════════════════════════════════════════════════════
// V Shots — JioSaavn Web Provider (official webpage URL only)
// ═════════════════════════════════════════════════════════════════════════════

class JioSaavnWebProvider {
  JioSaavnWebProvider._();
  static final JioSaavnWebProvider instance = JioSaavnWebProvider._();

  Future<String?> resolveWebUrl({
    required String title,
    String artist = '',
    String? permalink,
  }) async {
    if (permalink != null && permalink.isNotEmpty) {
      if (isValidJioSaavnUrl(permalink)) return permalink;
    }
    final query = _buildSearchQuery(title, artist);
    if (query.isEmpty) return null;
    final encodedQuery = Uri.encodeComponent(query);
    return 'https://www.jiosaavn.com/search/songs/$encodedQuery';
  }

  String _buildSearchQuery(String title, String artist) {
    final parts = <String>[];
    if (title.isNotEmpty) parts.add(title);
    if (artist.isNotEmpty) parts.add(artist);
    return parts.join(' ');
  }

  static bool isValidJioSaavnUrl(String url) {
    final lower = url.toLowerCase().trim();
    if (!lower.startsWith('https://')) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    final validHosts = [
      'jiosaavn.com',
      'www.jiosaavn.com',
      'saavn.com',
      'www.saavn.com',
    ];
    if (!validHosts.any((h) => host == h || host.endsWith('.$h'))) return false;
    for (final ext in ['.mp3', '.m4a', '.m3u8', '.mp4', '.mpd', '.aac']) {
      if (lower.contains(ext)) return false;
    }
    for (final p in ['cdn', 'stream', 'download', 'media']) {
      if (host.contains(p)) return false;
    }
    return uri.scheme == 'https';
  }
}

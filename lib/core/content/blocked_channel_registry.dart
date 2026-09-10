// ═════════════════════════════════════════════════════════════════════════════
// V Shots — BlockedChannelRegistry (manual channel blocklist, authoritative)
// ═════════════════════════════════════════════════════════════════════════════
//
// SINGLE SOURCE OF TRUTH for channels the owner has manually removed from
// V Shots. Every content path (Home, For You, Discovery, Search, AI/artist
// recommendations, playlists, autoplay/queue, prefetch, caches) must pass
// [isContentAllowed] / [BlockedChannelRegistry.isBlocked] BEFORE the item
// can be displayed, queued, cached-for-display, or played.
//
// Matching is authoritative and bypass-resistant:
//   1. YouTube channel ID (UC…) — exact, stable, preferred.
//   2. @handle — exact after normalization.
//   3. Canonical URL forms — /channel/UC…, /@handle, /c/Name, /user/Name.
//   4. Normalized display-name / alias equality (case-, punctuation- and
//      spacing-insensitive). NO substring matching — an unrelated channel
//      whose name merely CONTAINS a blocked name is never blocked.
//
// MAINTENANCE: to block a new channel, add one [BlockedChannelEntry] to
// [BlockedChannelRegistry.entries] below (prefer the UC… channel ID — take
// it from the channel page URL). Tests live in
// test/core/content/blocked_channel_registry_test.dart.
// ═════════════════════════════════════════════════════════════════════════════

/// One manually blocked channel.
class BlockedChannelEntry {
  const BlockedChannelEntry({
    required this.displayName,
    this.channelId,
    this.handle,
    this.aliases = const [],
  });

  /// Stable YouTube channel id (`UC…`). Preferred identifier.
  final String? channelId;

  /// Channel handle without `@` (e.g. `prghindiaudio`).
  final String? handle;

  /// The name the owner used when requesting the block (kept verbatim for
  /// documentation; matching uses normalized forms).
  final String displayName;

  /// Extra name variants seen in the wild (rebrands, casing/punctuation
  /// variants, "Official" suffixes…). Matched by normalized equality.
  final List<String> aliases;
}

class BlockedChannelRegistry {
  BlockedChannelRegistry._() {
    _buildIndex();
  }

  static final BlockedChannelRegistry instance = BlockedChannelRegistry._();

  // ═══════════════════════════════════════════════════════════════════
  // SOURCE OF TRUTH — owner-maintained blocklist (2026-09-10)
  // ═══════════════════════════════════════════════════════════════════
  static const List<BlockedChannelEntry> entries = [
    BlockedChannelEntry(
      displayName: 'Prakash Jojawar',
      channelId: 'UCigy0uZUtH6V2PAYHftQ4Qg',
      handle: 'prghindiaudio',
      aliases: ['PRG Hindi Audio', 'Prakash Jojawar Official'],
    ),
    BlockedChannelEntry(
      displayName: 'Rawat Super Star Music',
      // No stable UC… id located at block time — matched by name variants.
      aliases: ['Rawat Superstar Music', 'Rawat Super Star'],
    ),
    BlockedChannelEntry(
      displayName: 'Gaurav Mali',
      channelId: 'UCTNwxS7Cptx0J6tMPGGV9Dw',
      handle: 'GauravMalii',
      aliases: ['Gaurav Mali Official'],
    ),
  ];

  late final Set<String> _channelIds;
  late final Set<String> _handles;
  late final Set<String> _looseNames;

  void _buildIndex() {
    _channelIds = {};
    _handles = {};
    _looseNames = {};
    for (final e in entries) {
      final id = e.channelId;
      if (id != null && id.isNotEmpty) _channelIds.add(id);
      final handle = normalizeName(e.handle ?? '');
      if (handle.isNotEmpty) _handles.add(handle);
      for (final name in [e.displayName, ...e.aliases]) {
        final loose = looseKey(name);
        if (loose.isNotEmpty) _looseNames.add(loose);
      }
    }
  }

  /// Number of blocked channels (for diagnostics/tests).
  int get length => entries.length;

  /// Normalization for names/handles: lowercase, strip punctuation and
  /// decoration, collapse whitespace. `RAWAT  super-star` → `rawat super star`.
  static String normalizeName(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.isEmpty) return '';
    final sb = StringBuffer();
    var lastWasSpace = true;
    for (final ch in lower.runes) {
      final c = String.fromCharCode(ch);
      if (RegExp(r'[a-z0-9\u0900-\u097F]').hasMatch(c)) {
        sb.write(c);
        lastWasSpace = false;
      } else if (!lastWasSpace) {
        sb.write(' ');
        lastWasSpace = true;
      }
    }
    return sb.toString().trim();
  }

  /// Loose comparison key: normalized name with all spaces removed.
  /// Catches `RawatSuperStarMusic` vs `Rawat Super Star Music` and
  /// `prghindiaudio` vs `PRG Hindi Audio` style re-spacings.
  static String looseKey(String input) =>
      normalizeName(input).replaceAll(' ', '');

  /// Extracts an identifier from any common YouTube channel URL form.
  /// Returns `('id', 'UC…')`, `('handle', 'name')`, `('name', 'Name')`
  /// or `null` when nothing recognizable is present.
  static (String kind, String value)? parseChannelUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return null;
    // /channel/UC… — stable id, authoritative.
    final idMatch = RegExp(
      r'youtube\.com/channel/(UC[A-Za-z0-9_-]{20,})',
      caseSensitive: false,
    ).firstMatch(u);
    if (idMatch != null) return ('id', idMatch.group(1)!);
    // /@handle (www, m., music. — any subdomain).
    final handleMatch = RegExp(
      r'youtube\.com/@([A-Za-z0-9_.\-]+)',
      caseSensitive: false,
    ).firstMatch(u);
    if (handleMatch != null) return ('handle', handleMatch.group(1)!);
    // /c/Name or /user/Name legacy vanity forms.
    final nameMatch = RegExp(
      r'youtube\.com/(?:c|user)/([A-Za-z0-9_.\-]+)',
      caseSensitive: false,
    ).firstMatch(u);
    if (nameMatch != null) return ('name', nameMatch.group(1)!);
    // Bare channel id passed as a "URL".
    if (RegExp(r'^UC[A-Za-z0-9_-]{20,}$').hasMatch(u)) return ('id', u);
    return null;
  }

  /// Authoritative blocked-channel check. Any non-null identifier matching
  /// is enough; every provided signal is checked.
  bool isBlocked({
    String? channelId,
    String? channelName,
    String? channelUrl,
    String? artist,
  }) {
    if (channelId != null && channelId.isNotEmpty) {
      if (_channelIds.contains(channelId)) return true;
    }
    if (channelUrl != null && channelUrl.isNotEmpty) {
      final parsed = parseChannelUrl(channelUrl);
      if (parsed != null) {
        switch (parsed.$1) {
          case 'id':
            if (_channelIds.contains(parsed.$2)) return true;
          case 'handle':
            if (_handles.contains(normalizeName(parsed.$2))) return true;
          case 'name':
            if (_looseNames.contains(looseKey(parsed.$2))) return true;
        }
      }
    }
    // Name checks use FULL normalized equality (never substring).
    for (final name in [channelName, artist]) {
      if (name == null || name.isEmpty) continue;
      if (_looseNames.contains(looseKey(name))) return true;
    }
    if (channelName != null && channelName.isNotEmpty) {
      final n = normalizeName(channelName);
      if (_handles.contains(n)) return true;
    }
    return false;
  }

  /// Track-level check against the app's existing `Map<String, dynamic>`
  /// track shape (`channelId`, `channelTitle`/`channel`, `channelUrl`,
  /// `artist`). This is THE content-eligibility helper every pipeline
  /// must call before display/queue/play.
  static bool isContentAllowed(Map<String, dynamic> track) {
    return !instance.isBlocked(
      channelId: track['channelId'] as String?,
      channelName:
          (track['channelTitle'] as String?) ?? (track['channel'] as String?),
      channelUrl: track['channelUrl'] as String?,
      artist: track['artist'] as String?,
    );
  }

  /// Convenience filter — returns only allowed tracks, order preserved.
  static List<Map<String, dynamic>> filterBlocked(
    Iterable<Map<String, dynamic>> tracks,
  ) {
    return tracks.where(isContentAllowed).toList();
  }

  /// Queue-level enforcement for the playback manager: removes blocked
  /// tracks from a queue and maps [startIndex] onto the sanitized list so
  /// the same track still starts when possible. Returns `(-1, [])` when
  /// nothing is eligible. This is the LAST line of defense before audio
  /// actually plays — caches and legacy lists can never sneak content
  /// past it.
  static (int, List<Map<String, dynamic>>) sanitizeQueue(
    List<Map<String, dynamic>> tracks,
    int startIndex,
  ) {
    final allowed = <Map<String, dynamic>>[];
    var mappedStart = 0;
    for (var i = 0; i < tracks.length; i++) {
      if (!isContentAllowed(tracks[i])) continue;
      if (i <= startIndex) mappedStart = allowed.length;
      allowed.add(tracks[i]);
    }
    if (allowed.isEmpty) return (-1, const []);
    return (mappedStart.clamp(0, allowed.length - 1), allowed);
  }
}

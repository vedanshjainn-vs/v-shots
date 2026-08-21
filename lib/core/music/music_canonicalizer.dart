// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music canonicalization / deduplication
// ═════════════════════════════════════════════════════════════════════════════
//
// The same song can appear as official audio / music video / topic upload /
// reupload. Canonicalization merges them so a shelf never shows five copies of
// one song. Key = normalized artist + normalized title.
//
// IMPORTANT: meaningful version markers are PRESERVED — "Song X", "Song X
// Remix", "Song X (Acoustic)", "Song X (Live)" remain distinct entities; only
// presentation noise (official/audio/lyrics brackets) is stripped.
// Preferred representation: official music video > official audio > official
// (any) > longer duration > first-seen.
// ═════════════════════════════════════════════════════════════════════════════

String _normalize(String input) {
  final lower = input.toLowerCase();
  // Strip only presentation noise, preserving version markers.
  final stripped = lower
      .replaceAll(RegExp(r'\(official.*?\)'), ' ')
      .replaceAll(RegExp(r'\[official.*?\]'), ' ')
      .replaceAll(RegExp(r'\(audio.*?\)'), ' ')
      .replaceAll(RegExp(r'\[audio.*?\]'), ' ')
      .replaceAll(RegExp(r'\(lyric.*?\)'), ' ')
      .replaceAll(RegExp(r'\[lyric.*?\]'), ' ')
      .replaceAll(RegExp(r'\(hd.*?\)'), ' ')
      .replaceAll(RegExp(r'\(4k.*?\)'), ' ')
      .replaceAll(RegExp(r'\(1080p.*?\)'), ' ');
  final alnum = stripped.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  return alnum.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Canonical identity key for a track: normalizedArtist|normalizedTitle.
String canonicalMusicKey(Map<String, dynamic> track) {
  final artist = _normalize((track['artist'] as String?) ?? '');
  final title = _normalize((track['title'] as String?) ?? '');
  return '$artist|$title';
}

/// Representation preference rank (lower = better): official music video,
/// then official audio, then any official, then longer duration, then first.
int _representationRank(Map<String, dynamic> track) {
  final title = ((track['title'] as String?) ?? '').toLowerCase();
  final official = track['isOfficial'] == true;
  if (official && title.contains('video')) return 0;
  if (official && title.contains('mv')) return 0;
  if (official && title.contains('audio')) return 1;
  if (official) return 2;
  if (title.contains('video') || title.contains('mv')) return 3;
  if (title.contains('audio')) return 4;
  return 5;
}

/// Merges duplicate representations of the same song into ONE canonical item.
/// Preference: representation rank, then longer duration, then first-seen.
/// Order of surviving items follows first occurrence.
List<Map<String, dynamic>> deduplicateMusicItems(
  List<Map<String, dynamic>> tracks,
) {
  final byKey = <String, Map<String, dynamic>>{};
  final ranks = <String, int>{};
  for (final track in tracks) {
    final key = canonicalMusicKey(track);
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = track;
      ranks[key] = _representationRank(track);
      continue;
    }
    final newRank = _representationRank(track);
    final existingDuration = existing['duration'] as int? ?? 0;
    final newDuration = track['duration'] as int? ?? 0;
    final replace =
        newRank < ranks[key]! ||
        (newRank == ranks[key]! && newDuration > existingDuration);
    if (replace) {
      byKey[key] = track;
      ranks[key] = newRank;
    }
  }
  return byKey.values.toList();
}

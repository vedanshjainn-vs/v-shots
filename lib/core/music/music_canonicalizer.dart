// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music canonicalization / deduplication
// ═════════════════════════════════════════════════════════════════════════════
//
// The same song can appear as official audio / music video / topic upload /
// reupload. Canonicalization merges them so a shelf never shows five copies of
// one song. Key = normalized artist + normalized title (strip non-alphanumerics
// and common release-noise suffixes). Preferred representation = official
// first, then longest duration, then first-seen.
// ═════════════════════════════════════════════════════════════════════════════

String _normalize(String input) {
  final lower = input.toLowerCase();
  final stripped = lower
      .replaceAll(RegExp(r'\(official.*?\)'), ' ')
      .replaceAll(RegExp(r'\[official.*?\]'), ' ')
      .replaceAll(RegExp(r'\(audio.*?\)'), ' ')
      .replaceAll(RegExp(r'\[audio.*?\]'), ' ')
      .replaceAll(RegExp(r'\(lyric.*?\)'), ' ')
      .replaceAll(RegExp(r'\[lyric.*?\]'), ' ');
  final alnum = stripped.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  return alnum.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Canonical identity key for a track: normalizedArtist|normalizedTitle.
String canonicalMusicKey(Map<String, dynamic> track) {
  final artist = _normalize((track['artist'] as String?) ?? '');
  final title = _normalize((track['title'] as String?) ?? '');
  return '$artist|$title';
}

/// Merges duplicate representations of the same song into ONE canonical item.
/// Preference: official/verified first, then longer duration, then first-seen.
/// Order of the surviving items is preserved (first occurrence wins the slot).
List<Map<String, dynamic>> deduplicateMusicItems(
  List<Map<String, dynamic>> tracks,
) {
  final byKey = <String, Map<String, dynamic>>{};
  for (final track in tracks) {
    final key = canonicalMusicKey(track);
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = track;
      continue;
    }
    // Prefer the official representation over a duplicate upload.
    final existingOfficial = existing['isOfficial'] == true;
    final newOfficial = track['isOfficial'] == true;
    final existingDuration = existing['duration'] as int? ?? 0;
    final newDuration = track['duration'] as int? ?? 0;
    if (newOfficial && !existingOfficial) {
      byKey[key] = track;
    } else if (newOfficial == existingOfficial &&
        newDuration > existingDuration) {
      byKey[key] = track;
    }
  }
  return byKey.values.toList();
}

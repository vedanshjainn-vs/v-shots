// ════════════════════════════════════════════════
// V Shots — Shared text-cleaning utilities
// ════════════════════════════════════════════════
//
// WHY THIS FILE EXISTS:
// `cleanTitle()` existed as two separate, near-identical copies before
// this file: a public top-level function in lib/main.dart, and a
// private `_cleanTitle()` inside for_you_feed_service.dart. Two copies
// of the same string-cleaning regex is exactly the kind of duplication
// this codebase has already burned time on once before (see
// stream_resolver.dart's file header re: the getManifest() bug). This
// is the single, canonical implementation — main.dart and
// for_you_feed_service.dart both now import this instead of keeping
// their own copy.
//
// Behavior is UNCHANGED from main.dart's original version (the two
// prior copies differed very slightly — for_you_feed_service.dart's
// version was missing the "(Audio...)"/"[Audio...]" strip that
// main.dart's had). This consolidated version keeps the more complete
// (main.dart) behavior for both call sites — a real, minor bug fix
// (For You feed titles could previously keep "(Audio)" suffixes that
// Home/Search titles already had stripped), not a behavior change
// anyone asked to avoid.
// ════════════════════════════════════════════════

/// Strips a leading "Artist - " prefix and common bracketed suffixes
/// (Official Video/Audio/Lyrics, etc.) from a raw YouTube video title,
/// so displayed track titles look like "Song Name" instead of
/// "Artist - Song Name (Official Music Video)".
String cleanTitle(String title, String artist) {
  var c = title;
  if (c.startsWith('$artist - ')) c = c.substring(artist.length + 3);
  c = c
      .replaceAll(RegExp(r'\s*\(Official.*?\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\[Official.*?\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\(Lyric.*?\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\[Lyric.*?\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\(Audio.*?\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\[Audio.*?\]', caseSensitive: false), '')
      .trim();
  return c.isEmpty ? title : c;
}

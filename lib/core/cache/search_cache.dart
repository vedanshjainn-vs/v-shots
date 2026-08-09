// ════════════════════════════════════════════════
// V Shots — Short-TTL in-memory search result cache
// ════════════════════════════════════════════════
//
// WHY THIS EXISTS (per user-approved refinement list, Section B #3):
// Previously, every single Home screen visit re-ran a fresh YouTube
// search from zero — even reopening the app 10 seconds after closing
// it triggered the exact same "Trending Now"/"New Releases" search
// queries again, with a full-screen shimmer blocking the UI until
// both returned. This cache lets a Home reload within a short window
// show the previous result INSTANTLY while a fresh fetch happens
// quietly in the background (stale-while-revalidate), rather than
// showing a shimmer for a query that was already answered moments ago.
//
// Deliberately simple (in-memory, process-lifetime only, short TTL) —
// this is not meant to be a durable cache (that's LocalLibrary's job
// for things that should survive app restarts); it exists purely to
// avoid redundant network round-trips within a single app session.
// ════════════════════════════════════════════════

class _CacheEntry {
  _CacheEntry(this.value, this.expiresAt);
  final List<Map<String, dynamic>> value;
  final DateTime expiresAt;
}

class SearchCache {
  SearchCache._();
  static final SearchCache instance = SearchCache._();

  final Map<String, _CacheEntry> _entries = {};

  /// How long a cached result is considered "fresh enough to reuse
  /// instantly." Chosen as a few minutes: long enough that reopening
  /// the app shortly after closing it (or switching tabs and back)
  /// feels instant, short enough that "Trending Now" doesn't go stale
  /// for hours.
  static const Duration defaultTtl = Duration(minutes: 5);

  /// Returns the cached value for [key] if present, regardless of
  /// whether it has expired — callers implementing stale-while-
  /// revalidate should show this immediately, then check [isFresh] to
  /// decide whether to also kick off a background refresh.
  List<Map<String, dynamic>>? get(String key) => _entries[key]?.value;

  bool isFresh(String key) {
    final entry = _entries[key];
    if (entry == null) return false;
    return DateTime.now().isBefore(entry.expiresAt);
  }

  void set(String key, List<Map<String, dynamic>> value, {Duration? ttl}) {
    _entries[key] = _CacheEntry(value, DateTime.now().add(ttl ?? defaultTtl));
  }

  void clear() => _entries.clear();
}

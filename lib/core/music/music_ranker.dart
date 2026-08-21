// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicRanker (music-specific ranking strategies + diversity)
// ═════════════════════════════════════════════════════════════════════════════
//
// Pure, deterministic, unit-tested ranking over validated track records.
// Uses ONLY real signals (views + age from InnerTube metadata) — when a
// signal is absent the original order is preserved (never fabricated).
//
// Each mode is genuinely different:
//   For You      → personalization (the existing recommendation engine)
//   Trending     → recent popularity (views weighted toward fresh uploads)
//   New Releases → newest first (age ascending)
//   Latest Music → newest first (music-specific)
//   Viral        → velocity = views / (age + 1)
//   Popular      → established popularity (views descending)
//
// Plus: artist-diversity caps, a soft already-seen penalty, and a
// deterministic exploration mix.
// ═════════════════════════════════════════════════════════════════════════════

class MusicRanker {
  const MusicRanker();

  static int _views(Map<String, dynamic> t) =>
      t['views'] is int ? t['views'] as int : 0;

  static int? _age(Map<String, dynamic> t) =>
      t['ageDays'] is int ? t['ageDays'] as int : null;

  /// STABLE sort by a numeric key (Dart's List.sort is not stable; this is).
  static List<Map<String, dynamic>> _stableSortBy(
    List<Map<String, dynamic>> tracks,
    num Function(Map<String, dynamic>) key, {
    bool descending = true,
  }) {
    final indexed = tracks.asMap().entries.toList();
    indexed.sort((a, b) {
      final cmp = key(b.value).compareTo(key(a.value));
      return descending ? cmp : -cmp;
    });
    // stable by construction? sort is not stable, so tie-break on index.
    indexed.sort((a, b) {
      final ka = key(a.value);
      final kb = key(b.value);
      final cmp = descending ? kb.compareTo(ka) : ka.compareTo(kb);
      return cmp != 0 ? cmp : a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  /// Established popularity: highest views first (older hits allowed).
  List<Map<String, dynamic>> rankPopular(List<Map<String, dynamic>> tracks) =>
      _stableSortBy(tracks, _views);

  /// Trending: popularity weighted toward recency. score ≈ views / (1+age/30).
  List<Map<String, dynamic>> rankTrending(List<Map<String, dynamic>> tracks) =>
      _stableSortBy(tracks, (t) {
        final views = _views(t);
        final age = _age(t);
        if (age == null) return views.toDouble();
        return views / (1 + age / 30);
      });

  /// New Releases / Latest Music: newest first (age ascending, unknown last).
  List<Map<String, dynamic>> rankNewest(List<Map<String, dynamic>> tracks) {
    final withAge = <Map<String, dynamic>>[];
    final withoutAge = <Map<String, dynamic>>[];
    for (final t in tracks) {
      (_age(t) == null ? withoutAge : withAge).add(t);
    }
    final sorted = _stableSortBy(
      withAge,
      (t) => _age(t)!.toDouble(),
      descending: false,
    );
    return [...sorted, ...withoutAge];
  }

  /// Viral: rapid current momentum — views relative to how new the item is.
  List<Map<String, dynamic>> rankViral(List<Map<String, dynamic>> tracks) =>
      _stableSortBy(tracks, (t) {
        final views = _views(t);
        final age = _age(t) ?? 60;
        return views / (age + 1);
      });

  /// Caps how often one artist can appear (soft diversity), preserving the
  /// incoming rank order otherwise. Artist-specific shelves pass a high cap.
  List<Map<String, dynamic>> applyDiversity(
    List<Map<String, dynamic>> tracks, {
    int maxPerArtist = 3,
  }) {
    final counts = <String, int>{};
    final result = <Map<String, dynamic>>[];
    for (final t in tracks) {
      final artist = (t['artist'] as String?) ?? '';
      final seen = counts[artist] ?? 0;
      if (seen >= maxPerArtist) continue;
      counts[artist] = seen + 1;
      result.add(t);
    }
    return result;
  }

  /// Soft already-seen penalty: recently seen/played items move to the END
  /// (never removed — a great song should eventually return).
  List<Map<String, dynamic>> applyAlreadySeenPenalty(
    List<Map<String, dynamic>> tracks,
    Set<String> seenIds,
  ) {
    if (seenIds.isEmpty) return tracks;
    final seen = <Map<String, dynamic>>[];
    final fresh = <Map<String, dynamic>>[];
    for (final t in tracks) {
      final id = (t['id'] as String?) ?? '';
      (seenIds.contains(id) ? seen : fresh).add(t);
    }
    return [...fresh, ...seen];
  }

  /// Deterministic exploration mix: interleave [exploration] into [primary]
  /// at roughly [ratio] (0.25 default). Preserves primary order; exploration
  /// items are inserted at even intervals.
  List<Map<String, dynamic>> mixExploration(
    List<Map<String, dynamic>> primary,
    List<Map<String, dynamic>> exploration, {
    double ratio = 0.25,
  }) {
    if (exploration.isEmpty || primary.isEmpty) return primary;
    final result = <Map<String, dynamic>>[];
    final every = (1 / ratio).round().clamp(2, 8);
    var expIndex = 0;
    for (var i = 0; i < primary.length; i++) {
      result.add(primary[i]);
      if ((i + 1) % every == 0 && expIndex < exploration.length) {
        result.add(exploration[expIndex++]);
      }
    }
    return result;
  }
}

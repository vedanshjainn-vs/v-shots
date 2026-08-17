// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music exploration mixing (exploit vs explore)
// ═════════════════════════════════════════════════════════════════════════════
//
// Interleaves exploration candidates into the primary feed at a configurable
// ratio (default 25%). Exploration = similar/adjacent/new/regional — never a
// random YouTube video (that is the catalog validator's job to reject).
// ═════════════════════════════════════════════════════════════════════════════

class MusicExploration {
  const MusicExploration({this.ratio = 0.25});

  final double ratio;

  /// Interleaves [exploration] into [primary] at [ratio]. Preserves primary
  /// order; exploration items are inserted at even intervals. Idempotent for
  /// empty exploration.
  List<T> mix<T>(List<T> primary, List<T> exploration) {
    if (exploration.isEmpty || primary.isEmpty) return primary;
    final every = (1 / ratio).round().clamp(2, 8);
    final result = <T>[];
    var exp = 0;
    for (var i = 0; i < primary.length; i++) {
      result.add(primary[i]);
      if ((i + 1) % every == 0 && exp < exploration.length) {
        result.add(exploration[exp++]);
      }
    }
    return result;
  }
}

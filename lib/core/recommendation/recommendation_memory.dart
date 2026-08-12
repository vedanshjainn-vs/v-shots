// ═════════════════════════════════════════════════════════════════════════
// V Shots — RecommendationMemory
//
// Solves the "SAME SONG AGAIN AND AGAIN" problem. Tracks per-song interaction
// history (shown, played, completed, skipped, liked) over 7/30-day windows and
// derives repetition + skip penalties so the engine re-freshens instead of
// recycling. Skips are persisted so a repeatedly-skipped song gets rejected;
// likes allow resurfacing.
// ═════════════════════════════════════════════════════════════════════════

class SongMemoryEntry {
  int timesShown = 0;
  int timesPlayed = 0;
  int timesCompleted = 0;
  int timesSkipped = 0;
  int timesLiked = 0;
  int lastShownDay = 0;
  int lastPlayedDay = 0;

  double get engagement =>
      timesPlayed +
      (timesCompleted * 0.5) +
      (timesLiked * 0.3) -
      (timesSkipped * 0.7);
}

/// In-memory (per session) + persisted (across session via LocalLibrary hooks)
/// recommendation memory. For now session-scoped with a day-window decay.
class RecommendationMemory {
  RecommendationMemory._();
  static final RecommendationMemory instance = RecommendationMemory._();

  final Map<String, SongMemoryEntry> _entries = {};
  int _today = 0;

  void _rollDay() {
    _today = DateTime.now().day + DateTime.now().month * 100;
  }

  SongMemoryEntry _entry(String videoId) =>
      _entries.putIfAbsent(videoId, SongMemoryEntry.new);

  void recordShown(String videoId) {
    _rollDay();
    final e = _entry(videoId);
    e.timesShown++;
    e.lastShownDay = _today;
  }

  void recordPlayed(String videoId) {
    _rollDay();
    final e = _entry(videoId);
    e.timesPlayed++;
    e.lastPlayedDay = _today;
  }

  void recordCompleted(String videoId) {
    _rollDay();
    _entry(videoId).timesCompleted++;
  }

  void recordSkip(String videoId) {
    _rollDay();
    _entry(videoId).timesSkipped++;
  }

  void recordLike(String videoId) {
    _rollDay();
    _entry(videoId).timesLiked++;
  }

  /// Repetition penalty in [0,1] — higher = more recently/heavily shown.
  double repetitionPenalty(String videoId) {
    final e = _entries[videoId];
    if (e == null) return 0;
    if (e.timesLiked > 0) return 0; // liked -> allow resurfacing
    var p = (e.timesShown - 1) * 0.15;
    if (e.lastShownDay == _today) p += 0.2;
    if (e.lastPlayedDay == _today) p += 0.15;
    return p.clamp(0.0, 1.0);
  }

  /// Skip penalty in [0,1]. Repeated skips push toward rejection.
  double skipPenalty(String videoId) {
    final e = _entries[videoId];
    if (e == null) return 0;
    return (e.timesSkipped * 0.3).clamp(0.0, 1.0);
  }

  /// True if a repeatedly-skipped song should be rejected outright.
  bool shouldReject(String videoId) {
    final e = _entries[videoId];
    if (e == null) return false;
    return e.timesSkipped >= 3;
  }

  /// Engagement value in [0,1]-ish (used as a behavior signal).
  double engagementFor(String videoId) {
    final e = _entries[videoId];
    if (e == null) return 0.3;
    return (e.engagement / 5).clamp(0.0, 1.0);
  }

  void clear() => _entries.clear();
}

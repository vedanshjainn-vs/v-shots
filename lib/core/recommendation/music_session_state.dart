// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicSessionState (per-session recommendation state)
// ═════════════════════════════════════════════════════════════════════════════

class MusicSessionState {
  /// Canonical song ids already emitted THIS session (hard dedupe).
  final Set<String> emittedSongIds = {};

  /// Raw video ids to exclude from fetches this session.
  final Set<String> excludeVideoIds = {};

  /// Bumped on every new request; callers use it to discard stale responses.
  int requestToken = 0;

  void reset() {
    emittedSongIds.clear();
    excludeVideoIds.clear();
    requestToken = 0;
  }

  bool emitSong(String canonicalSongId, String videoId) {
    if (canonicalSongId.isEmpty) return false;
    if (emittedSongIds.contains(canonicalSongId)) return false;
    emittedSongIds.add(canonicalSongId);
    excludeVideoIds.add(videoId);
    return true;
  }
}

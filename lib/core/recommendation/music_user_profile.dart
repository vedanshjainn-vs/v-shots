// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicUserProfile (multi-dimensional taste)
// ═════════════════════════════════════════════════════════════════════════════
//
// Extends the existing taste model (SignalStore → TasteProfileBuilder) with
// language / mood / album / song affinities and recent lists. It does NOT
// duplicate SignalStore/TasteProfile — it reuses them and ADDS dimensions.
// ═════════════════════════════════════════════════════════════════════════════

class MusicUserProfile {
  const MusicUserProfile({
    required this.artistAffinity,
    required this.genreAffinity,
    required this.languageAffinity,
    required this.moodAffinity,
    required this.albumAffinity,
    required this.songAffinity,
    required this.artistSkipPenalty,
    required this.recentArtists,
    required this.recentSongs,
  });

  final Map<String, double> artistAffinity;
  final Map<String, double> genreAffinity;
  final Map<String, double> languageAffinity;
  final Map<String, double> moodAffinity;
  final Map<String, double> albumAffinity;
  final Map<String, double> songAffinity;
  final Map<String, double> artistSkipPenalty;
  final List<String> recentArtists;
  final List<String> recentSongs;

  bool get isEmpty =>
      artistAffinity.isEmpty &&
      languageAffinity.isEmpty &&
      moodAffinity.isEmpty &&
      recentArtists.isEmpty;

  List<String> get topArtists {
    final sorted = artistAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  List<String> get topGenres {
    final sorted = genreAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  List<String> get topLanguages {
    final sorted = languageAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  List<String> get topMoods {
    final sorted = moodAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }
}

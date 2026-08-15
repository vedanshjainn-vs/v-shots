// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — music_core / track normalizer (vision §5)
//
// Track-identity resolution: normalizes titles/artists and classifies version
// relationships so "Song", "Song - Remastered", "Song (Official Audio)", and
// "Song - Live" are NOT incorrectly merged into one track, while genuine
// duplicates ARE collapsed. This is used for dedup + identity, not playback.
// ═════════════════════════════════════════════════════════════════════════

/// Version relationships between two tracks of the same base work.
enum TrackVersion {
  original,
  remastered,
  live,
  acoustic,
  spedUp,
  slowed,
  instrumental,
  karaoke,
  cover,
  remix,
  radioEdit,
  extended,
}

class TrackNormalizer {
  const TrackNormalizer();

  static final _stripPatterns = [
    RegExp(
        r'\((official|official video|official audio|official music video|lyric|lyrics|audio|video|hd|4k|full song|full video)\)',
        caseSensitive: false),
    RegExp(
        r'- (official|official video|official audio|music video|lyrics|audio|hd|4k|full song|full video)',
        caseSensitive: false),
  ];

  /// Normalizes a title for matching: lowercase, strip official/audio/lyric
  /// markers, collapse whitespace.
  String normalizeTitle(String title) {
    var t = title.trim();
    for (final re in _stripPatterns) {
      t = t.replaceAll(re, ' ');
    }
    t = t.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  /// Normalizes an artist name for matching.
  String normalizeArtist(String artist) {
    return artist.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Returns true if two (title, artist) pairs should be treated as the same
  /// base track (same normalized title + artist), regardless of version suffix.
  bool isSameBaseTrack({
    required String titleA,
    required String titleB,
    required String artistA,
    required String artistB,
  }) {
    if (normalizeArtist(artistA) != normalizeArtist(artistB)) return false;
    return normalizeTitle(titleA) == normalizeTitle(titleB);
  }

  /// Classifies the version relationship of [titleB] relative to [titleA].
  /// Returns [TrackVersion.original] when they are the same normalized base.
  TrackVersion versionOf(String baseTitle, String candidateTitle) {
    final a = baseTitle.toLowerCase();
    final b = candidateTitle.toLowerCase();
    if (normalizeTitle(a) == normalizeTitle(b)) return TrackVersion.original;
    if (_has(
        b, ['remaster', 'remastered', 'remastered 2015', '2011 remaster'])) {
      return TrackVersion.remastered;
    }
    if (_has(b, ['live', 'live at', 'live session'])) return TrackVersion.live;
    if (_has(b, ['acoustic'])) return TrackVersion.acoustic;
    if (_has(b, ['sped up', 'sped-up', 'speed up'])) return TrackVersion.spedUp;
    if (_has(b, ['slowed', 'slowed reverb'])) return TrackVersion.slowed;
    if (_has(b, ['instrumental'])) return TrackVersion.instrumental;
    if (_has(b, ['karaoke'])) return TrackVersion.karaoke;
    if (_has(b, ['cover'])) return TrackVersion.cover;
    if (_has(b, ['remix', 'club mix', 'dance mix'])) return TrackVersion.remix;
    if (_has(b, ['radio edit'])) return TrackVersion.radioEdit;
    if (_has(b, ['extended', 'extended mix'])) return TrackVersion.extended;
    return TrackVersion.original;
  }

  bool _has(String s, List<String> needles) {
    for (final n in needles) {
      if (s.contains(n)) return true;
    }
    return false;
  }
}

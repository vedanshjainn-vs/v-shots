// ═════════════════════════════════════════════════════════════════════════
// V Shots — Recommendation Engine: User Signals (Phase 7 / V2)
// ═════════════════════════════════════════════════════════════════════════

enum SignalType {
  play,
  playDuration, // carries `value` = seconds actually listened
  completed,
  skip, // carries `value` = seconds listened before skipping
  like,
  unlike,
  search, // carries `query` instead of a trackId (strongest explicit intent)
  addToPlaylist,
  removeFromPlaylist,
  replay, // same track played again within a short window
  playlistOpen, // carries `playlistTheme` or `query`
  playlistInteraction, // song played/completed within playlist
  discoveryListen, // long listen in Discovery vertical feed
  discoverySwipe, // swiped away in Discovery feed
}

class SignalEvent {
  const SignalEvent({
    required this.type,
    required this.timestamp,
    this.trackId,
    this.artist,
    this.title,
    this.query,
    this.value,
    this.playlistTheme,
    this.genre,
    this.language,
  });

  final SignalType type;
  final DateTime timestamp;

  /// Present for track-level signals (play/completed/skip/like/etc.);
  /// null for [SignalType.search] and [SignalType.playlistOpen].
  final String? trackId;
  final String? artist;
  final String? title;

  /// Present for [SignalType.search] or search-derived queries.
  final String? query;

  /// Present for [SignalType.playDuration] (seconds listened) and
  /// [SignalType.skip] (seconds listened before the skip).
  final double? value;

  /// Present for [SignalType.playlistOpen] or [SignalType.playlistInteraction].
  final String? playlistTheme;

  final String? genre;
  final String? language;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        if (trackId != null) 'trackId': trackId,
        if (artist != null) 'artist': artist,
        if (title != null) 'title': title,
        if (query != null) 'query': query,
        if (value != null) 'value': value,
        if (playlistTheme != null) 'playlistTheme': playlistTheme,
        if (genre != null) 'genre': genre,
        if (language != null) 'language': language,
      };

  factory SignalEvent.fromJson(Map<String, dynamic> json) {
    return SignalEvent(
      type: SignalType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SignalType.play,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      trackId: json['trackId'] as String?,
      artist: json['artist'] as String?,
      title: json['title'] as String?,
      query: json['query'] as String?,
      value: (json['value'] as num?)?.toDouble(),
      playlistTheme: json['playlistTheme'] as String?,
      genre: json['genre'] as String?,
      language: json['language'] as String?,
    );
  }
}

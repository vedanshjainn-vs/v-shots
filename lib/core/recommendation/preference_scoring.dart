import 'package:v_shots/core/storage/personalization_store.dart';

/// Immutable snapshot of the user's *stated* preferences (onboarding /
/// profile edits), captured once per feed build and reused for every
/// candidate — capturing is O(prefs), matching is O(1) set lookups.
///
/// Every matcher returns a normalized 0..1 affinity so callers can weight
/// it exactly like any other scoring feature. Absent data is a neutral 0,
/// never a fabricated score.
class PreferenceSnapshot {
  PreferenceSnapshot._({
    required Set<String> languages,
    required Set<String> artists,
    required Set<String> genres,
    required Set<String> songKeys,
    required Set<String> songTitles,
    required Set<String> songArtists,
  })  : _languages = languages,
        _artists = artists,
        _genres = genres,
        _songKeys = songKeys,
        _songTitles = songTitles,
        _songArtists = songArtists;

  final Set<String> _languages;
  final Set<String> _artists;
  final Set<String> _genres;
  final Set<String> _songKeys;
  final Set<String> _songTitles;
  final Set<String> _songArtists;

  /// Captures the current stated preferences. Pure read — safe to call
  /// from any scoring path; never triggers persistence or side effects.
  factory PreferenceSnapshot.capture([PersonalizationStore? store]) {
    final s = store ?? PersonalizationStore.instance;
    return PreferenceSnapshot._(
      languages: {
        for (final l in s.preferredLanguages)
          if (normalize(l).isNotEmpty) normalize(l),
      },
      artists: {
        for (final a in s.favoriteArtists)
          if (normalize(a).isNotEmpty) normalize(a),
      },
      genres: {
        for (final g in s.preferredGenres)
          if (normalize(g).isNotEmpty) normalize(g),
      },
      songKeys: {
        for (final song in s.favoriteSongs) _songKey(song.title, song.artist),
      },
      songTitles: {
        for (final song in s.favoriteSongs)
          if (normalize(song.title).isNotEmpty) normalize(song.title),
      },
      songArtists: {
        for (final song in s.favoriteSongs)
          if (normalize(song.artist).isNotEmpty) normalize(song.artist),
      },
    );
  }

  /// True when the user has stated nothing — every matcher will return 0.
  bool get isEmpty =>
      _languages.isEmpty &&
      _artists.isEmpty &&
      _genres.isEmpty &&
      _songKeys.isEmpty;

  bool get isNotEmpty => !isEmpty;

  /// Normalizes a human string for comparison: lowercase, collapse all
  /// non-alphanumerics to single spaces, trim.
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static String _songKey(String title, String artist) =>
      '${normalize(title)}|${normalize(artist)}';

  /// Splits a display artist string ("Arijit Singh, Shreya Ghoshal",
  /// "A ft. B") into the individual artist names it lists.
  static List<String> _artistSegments(String artist) => artist
      .toLowerCase()
      .split(RegExp(r'[,&/]| feat\.? | ft\.? | x '))
      .map(normalize)
      .where((s) => s.isNotEmpty)
      .toList();

  /// 1.0 when the candidate's language is a stated preference.
  double languageMatch(String? language) {
    if (language == null || language.isEmpty) return 0;
    return _languages.contains(normalize(language)) ? 1.0 : 0.0;
  }

  /// 1.0 when the candidate's artist (or any artist credited in a
  /// collaborative credit string) is a stated favorite artist.
  double artistMatch(String? artist) {
    if (artist == null || artist.isEmpty) return 0;
    if (_artists.isEmpty) return 0;
    final segments = _artistSegments(artist);
    if (segments.length == 1) {
      return _artists.contains(segments.first) ? 1.0 : 0.0;
    }
    for (final segment in segments) {
      if (_artists.contains(segment)) return 1.0;
    }
    return 0.0;
  }

  /// 1.0 when the candidate's genre/mood is a stated preference.
  double genreMatch(String? genre) {
    if (genre == null || genre.isEmpty) return 0;
    return _genres.contains(normalize(genre)) ? 1.0 : 0.0;
  }

  /// 1.0 for the exact favorite song (title AND artist), 0.5 when only
  /// the title matches (covers/re-editions of a favorited song are
  /// genuinely relevant), 0 otherwise.
  double songMatch({String? title, String? artist}) {
    if (_songKeys.isEmpty) return 0;
    final key = _songKey(title ?? '', artist ?? '');
    if (_songKeys.contains(key)) return 1.0;
    if (title != null && _songTitles.contains(normalize(title))) return 0.5;
    return 0.0;
  }

  /// True when [artist] matches any artist credited on a favorite song
  /// (used by candidate generators to seed "more from this artist").
  bool isFavoriteSongArtist(String artist) =>
      _songArtists.contains(normalize(artist));

  /// Soft bias tokens for query generation: languages first, then genres
  /// (they double as real search terms), capped so queries stay short.
  List<String> queryTokens({int max = 3}) => <String>[
        ..._languages.map(_denormalize),
        ..._genres.map(_denormalize),
      ].take(max).toList();

  /// Normalized (compare-ready) tokens for text matching against shelf
  /// metadata etc. Raw normalized forms, not re-cased.
  List<String> get artistTokens => _artists.toList();
  List<String> get languageTokens => _languages.toList();
  List<String> get genreTokens => _genres.toList();

  String _denormalize(String normalized) =>
      normalized.split(' ').map(_titleCase).join(' ');

  static String _titleCase(String word) =>
      word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);
}

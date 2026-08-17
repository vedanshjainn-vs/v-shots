// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicUserProfileBuilder
// ═════════════════════════════════════════════════════════════════════════════
//
// Builds the multi-dimensional taste profile from the EXISTING signal
// infrastructure (SignalStore.events + TasteProfileBuilder + LocalLibrary).
// Adds language/mood/song/album affinities and recent lists on top — never a
// second signal store.
// ═════════════════════════════════════════════════════════════════════════════

import '../music/music_entities.dart';
import '../storage/local_library.dart';
import 'music_recommendation_config.dart';
import 'music_user_profile.dart';
import 'signal_event.dart';
import 'signal_store.dart';
import 'taste_profile.dart';

class MusicUserProfileBuilder {
  MusicUserProfileBuilder({
    this.config = MusicRecommendationConfig.defaultConfig,
  });

  final MusicRecommendationConfig config;

  MusicUserProfile build() {
    final events = SignalStore.instance.events;
    final taste = TasteProfileBuilder().build(events: events); // reuse

    final languageAffinity = <String, double>{};
    final moodAffinity = <String, double>{};
    final songAffinity = <String, double>{};
    final albumAffinity = <String, double>{};

    for (final event in events) {
      final weight = _weightFor(event);
      if (weight == 0) continue;
      final decay = musicDecay(
        timestamp: event.timestamp,
        halfLifeHours: config.genreAffinityHalfLifeHours,
      );
      final text =
          '${event.title ?? ''} ${event.artist ?? ''} ${event.query ?? ''}'
              .toLowerCase();

      final language = _detectLanguage(text);
      if (language != null) {
        languageAffinity[language] =
            (languageAffinity[language] ?? 0) + weight * decay;
      }
      final mood = _detectMood(text);
      if (mood != null) {
        moodAffinity[mood] = (moodAffinity[mood] ?? 0) + weight * decay;
      }
      // Song affinity keyed by canonical identity (title + artist).
      if (event.title != null && event.title!.isNotEmpty && weight > 0) {
        final songKey = canonicalSongId(
          title: event.title!,
          artistName: event.artist,
          variant: detectMusicVariant(event.title!),
        );
        songAffinity[songKey] = (songAffinity[songKey] ?? 0) + weight * decay;
      }
    }
    _clamp(languageAffinity);
    _clamp(moodAffinity);
    _clamp(songAffinity);

    // Recents from LocalLibrary (most-recent-first, already persisted).
    final recent = LocalLibrary.instance.recentlyPlayed.value;
    final recentArtists = <String>[];
    final recentSongs = <String>[];
    final seenArtists = <String>{};
    for (final track in recent) {
      final artist = track['artist'] as String? ?? '';
      if (artist.isNotEmpty && seenArtists.add(artist)) {
        recentArtists.add(artist);
      }
      final title = track['title'] as String? ?? '';
      if (title.isNotEmpty) {
        recentSongs.add(
          canonicalSongId(
            title: title,
            artistName: artist,
            variant: detectMusicVariant(title),
          ),
        );
      }
      if (recentArtists.length >= 20 && recentSongs.length >= 20) break;
    }

    return MusicUserProfile(
      artistAffinity: taste.artistAffinity,
      genreAffinity: taste.genreAffinity,
      languageAffinity: languageAffinity,
      moodAffinity: moodAffinity,
      albumAffinity: albumAffinity, // no album signal in the pipeline (honest)
      songAffinity: songAffinity,
      artistSkipPenalty: taste.artistSkipPenalty,
      recentArtists: recentArtists,
      recentSongs: recentSongs,
    );
  }

  /// Same per-event weight scale as the existing taste engine (consistent,
  /// not a second, divergent scale).
  double _weightFor(SignalEvent event) {
    switch (event.type) {
      case SignalType.like:
        return MusicSignalWeights.like;
      case SignalType.replay:
        return MusicSignalWeights.replay;
      case SignalType.completed:
        return MusicSignalWeights.completed;
      case SignalType.addToPlaylist:
        return MusicSignalWeights.playlistAdd;
      case SignalType.playDuration:
        final seconds = event.value ?? 0;
        return seconds >= 60
            ? MusicSignalWeights.longListen
            : MusicSignalWeights.play;
      case SignalType.play:
        return MusicSignalWeights.play;
      case SignalType.unlike:
        return -1.0;
      case SignalType.skip:
        final seconds = event.value ?? 0;
        if (seconds < 10) return MusicSignalWeights.immediateSkip;
        if (seconds < 30) return MusicSignalWeights.shortSkip;
        return MusicSignalWeights.lateSkip;
      case SignalType.search:
      case SignalType.removeFromPlaylist:
        return 0;
    }
  }

  static String? _detectLanguage(String text) {
    const langs = {
      'punjabi': 'punjabi',
      'hindi': 'hindi',
      'bollywood': 'hindi',
      'tamil': 'tamil',
      'telugu': 'telugu',
      'bengali': 'bengali',
      'marathi': 'marathi',
      'gujarati': 'gujarati',
      'bhojpuri': 'bhojpuri',
      'haryanvi': 'haryanvi',
      'malayalam': 'malayalam',
      'kannada': 'kannada',
      'english': 'english',
      'k-pop': 'korean',
      'kpop': 'korean',
    };
    for (final e in langs.entries) {
      if (text.contains(e.key)) return e.value;
    }
    return null;
  }

  static String? _detectMood(String text) {
    const moods = {
      'romantic': 'romantic',
      'love song': 'romantic',
      'love': 'romantic',
      'sad': 'sad',
      'heartbreak': 'sad',
      'breakup': 'sad',
      'chill': 'chill',
      'lofi': 'chill',
      'lo-fi': 'chill',
      'party': 'party',
      'dance': 'party',
      'workout': 'workout',
      'gym': 'workout',
      'late night': 'late night',
      'peaceful': 'peaceful',
      'calm': 'peaceful',
      'meditation': 'peaceful',
      'feel good': 'feel good',
      'happy': 'feel good',
    };
    for (final e in moods.entries) {
      if (text.contains(e.key)) return e.value;
    }
    return null;
  }

  static void _clamp(Map<String, double> map) {
    map.updateAll((_, v) => v < 0 ? 0 : v);
  }
}

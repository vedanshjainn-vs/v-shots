// ════════════════════════════════════════════════
// Project Lyra — Content Type Enum
// ════════════════════════════════════════════════

/// Types of playable / browsable content.
enum ContentType {
  /// Single music track.
  track,

  /// Full album.
  album,

  /// Artist page.
  artist,

  /// User / system playlist.
  playlist,

  /// Podcast show.
  podcast,

  /// Single podcast episode.
  podcastEpisode,

  /// Audiobook.
  audiobook,

  /// Single audiobook chapter.
  audiobookChapter,

  /// AI-generated mix / station.
  aiMix,

  /// Music video.
  video;

  String get label => switch (this) {
        track => 'Track',
        album => 'Album',
        artist => 'Artist',
        playlist => 'Playlist',
        podcast => 'Podcast',
        podcastEpisode => 'Episode',
        audiobook => 'Audiobook',
        audiobookChapter => 'Chapter',
        aiMix => 'AI Mix',
        video => 'Video',
      };
}

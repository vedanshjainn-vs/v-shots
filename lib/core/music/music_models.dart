// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music domain model
// ═════════════════════════════════════════════════════════════════════════════
//
// Normalized music entity used by the music-first content pipeline. The app's
// runtime pipeline still flows `Map<String, dynamic>` track records (persisted
// by LocalLibrary, consumed everywhere) — VShotsMusicItem is the typed,
// validated VIEW of those records, with lossless to/from converters, so the
// validator/canonicalizer can work on structured data WITHOUT breaking any
// existing consumer. No fabricated metadata: every field comes from the
// source record or stays null.
// ═════════════════════════════════════════════════════════════════════════════

enum MusicContentType { song, musicVideo, album, playlist, artist }

enum MusicSource { youtubeMusic, youtube, cached, supabase }

/// Result of validating a raw content item as music.
class MusicValidationResult {
  const MusicValidationResult({
    required this.isMusic,
    required this.confidence,
    required this.reasons,
    this.rejectionReason,
  });

  final bool isMusic;
  final double confidence;
  final List<String> reasons;
  final String? rejectionReason;

  static const rejected = MusicValidationResult(
    isMusic: false,
    confidence: 0,
    reasons: [],
  );
}

/// Typed, normalized music item (view of a track record).
class VShotsMusicItem {
  const VShotsMusicItem({
    required this.id,
    this.youtubeVideoId,
    this.youtubePlaylistId,
    required this.title,
    this.artistName,
    this.artistId,
    this.albumName,
    this.albumId,
    this.artworkUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.releaseDate,
    this.contentType = MusicContentType.song,
    this.language,
    this.region,
    this.genre,
    this.moods = const [],
    this.channelId,
    this.channelName,
    this.source = MusicSource.youtubeMusic,
    this.isOfficial = false,
    this.musicConfidence = 0,
  });

  final String id;
  final String? youtubeVideoId;
  final String? youtubePlaylistId;
  final String title;
  final String? artistName;
  final String? artistId;
  final String? albumName;
  final String? albumId;
  final String? artworkUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final DateTime? releaseDate;
  final MusicContentType contentType;
  final String? language;
  final String? region;
  final String? genre;
  final List<String> moods;
  final String? channelId;
  final String? channelName;
  final MusicSource source;
  final bool isOfficial;
  final double musicConfidence;

  /// The app's canonical track record (id/title/artist/artwork/duration/
  /// isOfficial/channelId) — what flows into playback, queue, LocalLibrary.
  Map<String, dynamic> toTrackMap() => {
        'id': id,
        'title': title,
        'artist': artistName ?? channelName ?? 'Unknown Artist',
        'artwork': artworkUrl ?? thumbnailUrl ?? '',
        'duration': durationSeconds ?? 0,
        if (isOfficial) 'isOfficial': true,
        if (channelId != null && channelId!.isNotEmpty) 'channelId': channelId,
        if (channelName != null && channelName!.isNotEmpty)
          'channelName': channelName,
      };

  factory VShotsMusicItem.fromTrackMap(Map<String, dynamic> map) {
    return VShotsMusicItem(
      id: (map['id'] as String?) ?? '',
      youtubeVideoId: map['id'] as String?,
      title: (map['title'] as String?) ?? '',
      artistName: map['artist'] as String?,
      artworkUrl: map['artwork'] as String?,
      durationSeconds: map['duration'] as int?,
      channelId: map['channelId'] as String?,
      channelName: map['channelName'] as String?,
      isOfficial: map['isOfficial'] == true,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music domain model (typed, validated view of a track record)
// ═════════════════════════════════════════════════════════════════════════════
//
// The app's runtime pipeline flows `Map<String, dynamic>` track records
// (persisted by LocalLibrary, consumed everywhere). VShotsMusicItem is the
// typed, validated VIEW of those records with lossless to/from converters, so
// the validator/canonicalizer/ranker work on structured data WITHOUT breaking
// any existing consumer. No fabricated metadata: every field comes from the
// source record or stays null.
// ═════════════════════════════════════════════════════════════════════════════

enum MusicContentType { song, musicVideo, album, playlist, artist }

enum MusicSource { youtubeMusic, youtube, cached, supabase }

/// The KIND of a music representation — used to prefer the right playable
/// variant and to penalize unofficial uploads without blindly rejecting them.
enum MusicVariantType {
  official,
  officialMusicVideo,
  officialAudio,
  officialRemix,
  officialLive,
  cover,
  karaoke,
  slowedReverb,
  mashup,
  fanEdit,
  lyrics,
  unknown,
}

/// Result of validating a raw content item as music. Multi-signal: a single
/// keyword rule is explicitly NOT what decides acceptance.
class MusicValidationResult {
  const MusicValidationResult({
    required this.isMusic,
    required this.confidence,
    this.officialityScore = 0,
    this.metadataQualityScore = 0,
    this.musicEntityScore = 0,
    this.sourceTrustScore = 0,
    this.detectedContentType,
    this.variant = MusicVariantType.unknown,
    this.reasons = const [],
    this.rejectionReason,
  });

  final bool isMusic;

  /// Overall music confidence (0..1).
  final double confidence;

  /// How official the source looks (0..1) — continuous, not just a badge.
  final double officialityScore;

  /// Completeness of available metadata (0..1).
  final double metadataQualityScore;

  /// Evidence this is a real music entity (duration/title/etc., 0..1).
  final double musicEntityScore;

  /// Reliability of the originating source (0..1).
  final double sourceTrustScore;

  final MusicContentType? detectedContentType;
  final MusicVariantType variant;
  final List<String> reasons;
  final String? rejectionReason;

  static const rejected = MusicValidationResult(
    isMusic: false,
    confidence: 0,
    rejectionReason: 'UNKNOWN',
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
    this.viewCount,
    this.publishedDaysAgo,
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
  final int? viewCount;
  final int? publishedDaysAgo;

  /// The app's canonical track record — what flows into playback, queue,
  /// LocalLibrary.
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
        if (viewCount != null) 'views': viewCount,
        if (publishedDaysAgo != null) 'ageDays': publishedDaysAgo,
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
      viewCount: map['views'] is int ? map['views'] as int : null,
      publishedDaysAgo: map['ageDays'] is int ? map['ageDays'] as int : null,
    );
  }
}

/// Best artwork for a music card: prefer explicit artwork, then thumbnail,
/// then null (never fabricate a URL). Callers render a square crop on top.
String? preferredArtwork(Map<String, dynamic> track) {
  final artwork = track['artwork'] as String?;
  if (artwork != null && artwork.isNotEmpty) return artwork;
  final thumbnail = track['thumbnailUrl'] as String?;
  if (thumbnail != null && thumbnail.isNotEmpty) return thumbnail;
  return null;
}

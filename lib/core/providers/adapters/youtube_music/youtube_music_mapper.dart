// ════════════════════════════════════════════════
// V Shots — YouTube Music Mapper
// ════════════════════════════════════════════════
//
// Converts YouTube/YouTube Music data to Lyra's
// unified provider models. Keeps YouTube-specific
// data isolated from the rest of the app.
// ════════════════════════════════════════════════

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../models/provider_models.dart';

/// Maps YouTube data to Lyra provider models.
///
/// This is the ONLY place YouTube-specific types
/// are converted to Lyra types.
class YouTubeMusicMapper {
  // ═══════════════════════════════════════════════
  // VIDEO → TRACK
  // ═══════════════════════════════════════════════

  /// Convert a YouTube Video to a ProviderTrack.
  static ProviderTrack videoToTrack(Video video) {
    // Extract artist from channel name or title.
    final artist = _extractArtist(video.title, video.author);
    final title = _cleanTitle(video.title, artist);

    return ProviderTrack(
      id: video.id.value,
      title: title,
      artist: artist,
      artworkUrl: video.thumbnails.highResUrl.toString(),
      duration: video.duration ?? Duration.zero,
      isExplicit: _isExplicit(video.title),
      popularity: video.engagement.viewCount,
      metadata: {
        'youtube_id': video.id.value,
        'channel_id': video.channelId.value,
        'channel_name': video.author,
        'published_at': video.publishDate?.toIso8601String(),
        'description': video.description,
        'view_count': video.engagement.viewCount,
        'like_count': video.engagement.likeCount,
      },
    );
  }

  // ═══════════════════════════════════════════════
  // VIDEO → ALBUM (approximate)
  // ═══════════════════════════════════════════════

  /// Convert a YouTube Video to a ProviderAlbum (approximate).
  ///
  /// YouTube doesn't have native album support,
  /// so we approximate using video metadata.
  static ProviderAlbum videoToAlbum(Video video) {
    final artist = _extractArtist(video.title, video.author);

    return ProviderAlbum(
      id: video.id.value,
      title: _extractAlbumTitle(video.title, video.description),
      artist: artist,
      artworkUrl: video.thumbnails.highResUrl.toString(),
      releaseDate: video.publishDate?.toIso8601String(),
      metadata: {
        'youtube_id': video.id.value,
        'channel_id': video.channelId.value,
        'video_count': 1,
        'type': 'single',
      },
    );
  }

  // ═══════════════════════════════════════════════
  // CHANNEL → ARTIST
  // ═══════════════════════════════════════════════

  /// Convert a YouTube Channel to a ProviderArtist.
  static ProviderArtist channelToArtist(Channel channel) {
    return ProviderArtist(
      id: channel.id.value,
      name: channel.title,
      imageUrl: channel.logoUrl,
      biography: channel.description,
      followersCount: channel.subscribersCount ?? 0,
      isVerified: false,
      metadata: {
        'youtube_channel_id': channel.id.value,
        'banner_url': channel.bannerUrl,
        'country': channel.country,
      },
    );
  }

  // ═══════════════════════════════════════════════
  // PLAYLIST
  // ═══════════════════════════════════════════════

  /// Convert playlist metadata.
  static ProviderPlaylist playlistToModel(
    Playlist playlist,
    List<Video> videos,
  ) {
    return ProviderPlaylist(
      id: playlist.id.value,
      title: playlist.title,
      description: playlist.description,
      ownerName: playlist.author,
      trackCount: videos.length,
      metadata: {
        'youtube_playlist_id': playlist.id.value,
        'video_count': playlist.videoCount,
      },
    );
  }

  // ═══════════════════════════════════════════════
  // SEARCH RESULT
  // ═══════════════════════════════════════════════

  /// Convert search results to ProviderSearchResult.
  static ProviderSearchResult searchResultsToModel(
    List<Video> videos,
    String query,
  ) {
    final tracks = videos.map(videoToTrack).toList();

    // Extract unique artists from results.
    final artistMap = <String, ProviderArtist>{};
    for (final video in videos) {
      final channelId = video.channelId.value;
      if (!artistMap.containsKey(channelId)) {
        artistMap[channelId] = ProviderArtist(
          id: channelId,
          name: video.author,
          metadata: {'channel_id': channelId},
        );
      }
    }

    return ProviderSearchResult(
      tracks: tracks,
      artists: artistMap.values.toList(),
      totalResults: videos.length,
      query: query,
      providerId: 'youtube_music',
    );
  }

  // ═══════════════════════════════════════════════
  // STREAM INFO
  // ═══════════════════════════════════════════════

  /// Convert stream info to ProviderStreamInfo.
  static ProviderStreamInfo streamToModel(
    String videoId,
    String url,
    int bitrate,
    String codec,
  ) {
    // Determine quality from bitrate.
    final quality = _bitrateToQuality(bitrate);

    return ProviderStreamInfo(
      url: url,
      quality: quality,
      bitrateKbps: bitrate ~/ 1000,
      format: codec,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      metadata: {
        'youtube_video_id': videoId,
        'codec': codec,
      },
    );
  }

  // ═══════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════

  /// Extract artist name from video title or channel.
  static String _extractArtist(String title, String channelName) {
    // Try to extract from "Artist - Title" format.
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      if (parts.length >= 2) {
        return parts[0].trim();
      }
    }

    // Try to extract from "Artist | Title" format.
    if (title.contains(' | ')) {
      final parts = title.split(' | ');
      if (parts.length >= 2) {
        return parts[0].trim();
      }
    }

    // Fall back to channel name.
    return channelName;
  }

  /// Clean title by removing artist name and extra info.
  static String _cleanTitle(String title, String artist) {
    var cleaned = title;

    // Remove "Artist - " prefix.
    if (cleaned.startsWith('$artist - ')) {
      cleaned = cleaned.substring(artist.length + 3);
    }

    // Remove common suffixes.
    cleaned = cleaned
        .replaceAll(RegExp(r'\s*\(Official.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Official.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Lyric.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Lyric.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Audio.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Audio.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Music Video.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Music Video.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Feat\.?.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*ft\.?.*?(?=\s*$|\s*\()', caseSensitive: false), '')
        .trim();

    return cleaned.isEmpty ? title : cleaned;
  }

  /// Check if title suggests explicit content.
  static bool _isExplicit(String title) {
    final lower = title.toLowerCase();
    return lower.contains('[explicit]') ||
        lower.contains('(explicit)') ||
        lower.contains('explicit');
  }

  /// Extract album title from video title/description.
  static String _extractAlbumTitle(String title, String description) {
    // Try to find album name in description.
    final albumMatch = RegExp(r'Album:\s*(.+?)(?:\n|$)', caseSensitive: false)
        .firstMatch(description);
    if (albumMatch != null) {
      return albumMatch.group(1)!.trim();
    }

    // Use cleaned title as album name.
    return _cleanTitle(title, '');
  }

  /// Convert bitrate to quality enum.
  static StreamQuality _bitrateToQuality(int bitrateBps) {
    final kbps = bitrateBps ~/ 1000;
    if (kbps >= 256) return StreamQuality.lossless;
    if (kbps >= 192) return StreamQuality.high;
    if (kbps >= 128) return StreamQuality.normal;
    return StreamQuality.low;
  }
}

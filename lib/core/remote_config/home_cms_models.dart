// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Remote Home CMS models (pure, no I/O)
// ═════════════════════════════════════════════════════════════════════════════

int cmsAsInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

bool cmsAsBool(dynamic value, {bool fallback = true}) {
  if (value is bool) return value;
  if (value is String) {
    final v = value.toLowerCase().trim();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
  }
  return fallback;
}

String cmsAsString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final s = '$value'.trim();
  return s.isEmpty ? fallback : s;
}

/// One published Home row from `home_layout_config`.
class HomeCmsSection {
  const HomeCmsSection({
    required this.id,
    required this.sectionKey,
    required this.title,
    required this.subtitle,
    required this.sectionType,
    required this.sourceType,
    required this.sourceValue,
    required this.query,
    required this.sortOrder,
    required this.visible,
    required this.published,
    required this.maxItems,
    this.regionCode,
    this.categoryId,
    this.refreshMinutes = 60,
  });

  final String id;
  final String sectionKey;
  final String title;
  final String subtitle;
  final String sectionType;
  final String sourceType;
  final String sourceValue;
  final String query;
  final int sortOrder;
  final bool visible;
  final bool published;
  final int maxItems;
  final String? regionCode;
  final String? categoryId;
  final int refreshMinutes;

  factory HomeCmsSection.fromMap(Map<String, dynamic> row) {
    final id = cmsAsString(row['id'], cmsAsString(row['section_key']));
    final sourceValue = cmsAsString(
      row['source_value'],
      cmsAsString(row['query']),
    );
    return HomeCmsSection(
      id: id,
      sectionKey: cmsAsString(row['section_key'], id),
      title: cmsAsString(row['title'], 'Untitled'),
      subtitle: cmsAsString(row['subtitle']),
      sectionType: cmsAsString(row['section_type'], 'home_section'),
      sourceType: cmsAsString(row['source_type'], 'youtube_search'),
      sourceValue: sourceValue,
      query: cmsAsString(row['query'], sourceValue),
      sortOrder: cmsAsInt(row['sort_order'], 0),
      visible: cmsAsBool(row['visible']),
      published: cmsAsBool(row['published']),
      maxItems: cmsAsInt(row['max_items'], 15).clamp(1, 100),
      regionCode: cmsAsString(row['region_code']).isEmpty
          ? null
          : cmsAsString(row['region_code']),
      categoryId: cmsAsString(row['category_id']).isEmpty
          ? null
          : cmsAsString(row['category_id']),
      refreshMinutes: cmsAsInt(row['refresh_minutes'], 60),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'section_key': sectionKey,
        'title': title,
        'subtitle': subtitle,
        'section_type': sectionType,
        'source_type': sourceType,
        'source_value': sourceValue,
        'query': query,
        'sort_order': sortOrder,
        'visible': visible,
        'published': published,
        'max_items': maxItems,
        'region_code': regionCode,
        'category_id': categoryId,
        'refresh_minutes': refreshMinutes,
      };
}

/// One pinned track from `home_section_items` (youtube_manual shelves).
class HomeCmsItem {
  const HomeCmsItem({
    required this.id,
    required this.sectionId,
    required this.contentId,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.youtubeVideoId,
    required this.sortOrder,
    required this.enabled,
    this.jiosaavnUrl,
  });

  final String id;
  final String sectionId;
  final String contentId;
  final String title;
  final String artist;
  final String artworkUrl;
  final String youtubeVideoId;
  final int sortOrder;
  final bool enabled;
  final String? jiosaavnUrl;

  factory HomeCmsItem.fromMap(Map<String, dynamic> row) {
    final videoId = cmsAsString(
      row['youtube_video_id'],
      cmsAsString(row['content_id']),
    );
    final artwork = cmsAsString(row['artwork_url']);
    return HomeCmsItem(
      id: cmsAsString(row['id']),
      sectionId: cmsAsString(row['section_id']),
      contentId: cmsAsString(row['content_id'], videoId),
      title: cmsAsString(row['title'], 'Untitled'),
      artist: cmsAsString(row['artist']),
      artworkUrl: artwork.isNotEmpty
          ? artwork
          : (videoId.isEmpty
              ? ''
              : 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'),
      youtubeVideoId: videoId,
      sortOrder: cmsAsInt(row['sort_order'], 0),
      enabled: cmsAsBool(row['is_enabled']),
      jiosaavnUrl: cmsAsString(row['jiosaavn_url']).isEmpty
          ? null
          : cmsAsString(row['jiosaavn_url']),
    );
  }

  Map<String, dynamic> toTrackMap() => {
        'id': youtubeVideoId,
        'title': title,
        'artist': artist,
        'artwork': artworkUrl,
        'duration': 0,
        'url': youtubeVideoId.isEmpty
            ? ''
            : 'https://www.youtube.com/watch?v=$youtubeVideoId',
        if (jiosaavnUrl != null) 'jiosaavnUrl': jiosaavnUrl,
      };
}

// ════════════════════════════════════════════════
// Project Lyra — Home Entities
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_entities.freezed.dart';
part 'home_entities.g.dart';

/// Home feed containing multiple sections.
@freezed
class HomeFeed with _$HomeFeed {
  const factory HomeFeed({
    required List<HomeSection> sections,
    @Default([]) List<BannerItem> banners,
    DateTime? lastUpdated,
  }) = _HomeFeed;

  factory HomeFeed.fromJson(Map<String, dynamic> json) => _$HomeFeedFromJson(json);
}

/// A section in the home feed.
@freezed
class HomeSection with _$HomeSection {
  const factory HomeSection({
    required String id,
    required String title,
    String? subtitle,
    required HomeSectionType type,
    @Default([]) List<HomeItem> items,
    @Default(false) bool showViewAll,
    String? viewAllRoute,
  }) = _HomeSection;

  factory HomeSection.fromJson(Map<String, dynamic> json) => _$HomeSectionFromJson(json);
}

/// Type of home section.
enum HomeSectionType {
  recentlyPlayed,
  trending,
  newReleases,
  madeForYou,
  topCharts,
  featured,
  genre,
  artist,
  playlist,
}

/// A single item in a home section.
@freezed
class HomeItem with _$HomeItem {
  const factory HomeItem({
    required String id,
    required String title,
    String? subtitle,
    String? imageUrl,
    required HomeItemType type,
    @Default({}) Map<String, dynamic> metadata,
  }) = _HomeItem;

  factory HomeItem.fromJson(Map<String, dynamic> json) => _$HomeItemFromJson(json);
}

/// Type of home item.
enum HomeItemType {
  track,
  album,
  artist,
  playlist,
  podcast,
  audiobook,
}

/// Banner item for hero carousel.
@freezed
class BannerItem with _$BannerItem {
  const factory BannerItem({
    required String id,
    required String title,
    String? subtitle,
    required String imageUrl,
    String? actionUrl,
    String? actionText,
    @Default({}) Map<String, dynamic> metadata,
  }) = _BannerItem;

  factory BannerItem.fromJson(Map<String, dynamic> json) => _$BannerItemFromJson(json);
}

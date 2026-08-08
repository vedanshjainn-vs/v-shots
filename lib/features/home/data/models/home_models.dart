// ════════════════════════════════════════════════
// Project Lyra — Home Data Models
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/home_entities.dart';

part 'home_models.freezed.dart';
part 'home_models.g.dart';

@freezed
class HomeFeedModel with _$HomeFeedModel {
  const factory HomeFeedModel({
    @Default([]) List<HomeSectionModel> sections,
    @Default([]) List<BannerModel> banners,
    String? lastUpdated,
  }) = _HomeFeedModel;

  factory HomeFeedModel.fromJson(Map<String, dynamic> json) =>
      _$HomeFeedModelFromJson(json);
}

@freezed
class HomeSectionModel with _$HomeSectionModel {
  const factory HomeSectionModel({
    required String id,
    required String title,
    String? subtitle,
    @Default('recentlyPlayed') String type,
    @Default([]) List<HomeItemModel> items,
    @Default(false) bool showViewAll,
    String? viewAllRoute,
  }) = _HomeSectionModel;

  factory HomeSectionModel.fromJson(Map<String, dynamic> json) =>
      _$HomeSectionModelFromJson(json);
}

@freezed
class HomeItemModel with _$HomeItemModel {
  const factory HomeItemModel({
    required String id,
    required String title,
    String? subtitle,
    String? imageUrl,
    @Default('track') String type,
    @Default({}) Map<String, dynamic> metadata,
  }) = _HomeItemModel;

  factory HomeItemModel.fromJson(Map<String, dynamic> json) =>
      _$HomeItemModelFromJson(json);
}

@freezed
class BannerModel with _$BannerModel {
  const factory BannerModel({
    required String id,
    required String title,
    String? subtitle,
    required String imageUrl,
    String? actionUrl,
    String? actionText,
    @Default({}) Map<String, dynamic> metadata,
  }) = _BannerModel;

  factory BannerModel.fromJson(Map<String, dynamic> json) =>
      _$BannerModelFromJson(json);
}

/// Extensions for entity conversion.
extension HomeFeedModelX on HomeFeedModel {
  HomeFeed toEntity() => HomeFeed(
        sections: sections.map((s) => s.toEntity()).toList(),
        banners: banners.map((b) => b.toEntity()).toList(),
        lastUpdated: lastUpdated != null ? DateTime.tryParse(lastUpdated!) : null,
      );
}

extension HomeSectionModelX on HomeSectionModel {
  HomeSection toEntity() => HomeSection(
        id: id,
        title: title,
        subtitle: subtitle,
        type: HomeSectionType.values.byName(type),
        items: items.map((i) => i.toEntity()).toList(),
        showViewAll: showViewAll,
        viewAllRoute: viewAllRoute,
      );
}

extension HomeItemModelX on HomeItemModel {
  HomeItem toEntity() => HomeItem(
        id: id,
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
        type: HomeItemType.values.byName(type),
        metadata: metadata,
      );
}

extension BannerModelX on BannerModel {
  BannerItem toEntity() => BannerItem(
        id: id,
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
        actionUrl: actionUrl,
        actionText: actionText,
        metadata: metadata,
      );
}

// ════════════════════════════════════════════════
// Project Lyra — Android Auto Service
// ════════════════════════════════════════════════
//
// Abstraction for Android Auto media integration.
// Provides browse categories, search, and playback
// for the car display. Architecture only.
// ════════════════════════════════════════════════

import '../state/playback_models.dart';

/// Service for Android Auto media integration.
///
/// Implements MediaBrowserService for Android Auto.
/// Provides browse categories and playback control.
abstract class AndroidAutoService {
  /// Initialize the Android Auto service.
  Future<void> initialize();

  /// Get browse root items (categories).
  Future<List<BrowseCategory>> getRootCategories();

  /// Get items for a browse category.
  Future<List<BrowseItem>> getCategoryItems(String categoryId);

  /// Search for content.
  Future<List<BrowseItem>> search(String query);

  /// Play a browse item.
  Future<void> playItem(BrowseItem item);

  /// Dispose resources.
  Future<void> dispose();
}

/// A browse category for Android Auto.
class BrowseCategory {
  const BrowseCategory({
    required this.id,
    required this.title,
    this.iconUri,
    this.itemCount,
  });

  final String id;
  final String title;
  final String? iconUri;
  final int? itemCount;
}

/// A browsable/playable item for Android Auto.
class BrowseItem {
  const BrowseItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.artUri,
    this.isPlayable = true,
    this.isBrowsable = false,
    this.queueItem,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? artUri;
  final bool isPlayable;
  final bool isBrowsable;
  final QueueItem? queueItem;
}

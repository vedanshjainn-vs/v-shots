// ════════════════════════════════════════════════
// Project Lyra — CarPlay Service
// ════════════════════════════════════════════════
//
// Abstraction for Apple CarPlay integration.
// Future iOS support placeholder.
// Architecture only.
// ════════════════════════════════════════════════

/// Service for Apple CarPlay integration.
///
/// Placeholder for future iOS implementation.
/// Mirrors Android Auto service interface.
abstract class CarPlayService {
  /// Initialize the CarPlay service.
  Future<void> initialize();

  /// Get root template categories.
  Future<List<CarPlayCategory>> getCategories();

  /// Get items for a category.
  Future<List<CarPlayItem>> getCategoryItems(String categoryId);

  /// Search for content.
  Future<List<CarPlayItem>> search(String query);

  /// Dispose resources.
  Future<void> dispose();
}

/// A CarPlay browse category.
class CarPlayCategory {
  const CarPlayCategory({
    required this.id,
    required this.title,
    this.image,
  });

  final String id;
  final String title;
  final String? image;
}

/// A CarPlay item.
class CarPlayItem {
  const CarPlayItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.artwork,
    this.duration,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? artwork;
  final Duration? duration;
}

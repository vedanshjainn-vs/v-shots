// ════════════════════════════════════════════════
// Project Lyra — Pagination Mixin
// ════════════════════════════════════════════════
//
// Infinite scroll pagination logic.
// Handles page tracking, loading more, and
// end-of-list detection.
// ════════════════════════════════════════════════

import '../../../config/constants/app_constants.dart';

/// Mixin for infinite scroll pagination.
///
/// ```dart
/// class TrendingNotifier extends StateNotifier<...> with PaginationMixin {
///   Future<void> loadMore() async {
///     if (!canLoadMore || isLoadingMorePage) return;
///     setLoadingMore();
///     final items = await repo.getTrending(page: nextPage, limit: pageSize);
///     appendItems(items);
///     if (items.length < pageSize) markEnd();
///   }
/// }
/// ```
mixin PaginationMixin<T> {
  List<T> _items = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  List<T> get items => _items;
  int get currentPage => _currentPage;
  bool get hasMore => _hasMore;
  bool get isLoadingMorePage => _isLoadingMore;
  bool get canLoadMore => _hasMore && !_isLoadingMore;
  int get pageSize => AppConstants.defaultPageSize;

  /// Set initial items (first page).
  void setItems(List<T> newItems) {
    _items = List.from(newItems);
    _currentPage = 1;
    _hasMore = newItems.length >= pageSize;
    _isLoadingMore = false;
  }

  /// Append items (next page).
  void appendItems(List<T> newItems) {
    _items = [..._items, ...newItems];
    _currentPage++;
    _hasMore = newItems.length >= pageSize;
    _isLoadingMore = false;
  }

  /// Mark that there are no more items.
  void markEnd() {
    _hasMore = false;
    _isLoadingMore = false;
  }

  /// Start loading more.
  void startLoadingMore() {
    _isLoadingMore = true;
  }

  /// Reset pagination state.
  void resetPagination() {
    _items = [];
    _currentPage = 1;
    _hasMore = true;
    _isLoadingMore = false;
  }

  /// Remove an item by predicate.
  void removeWhere(bool Function(T) test) {
    _items = _items.where((item) => !test(item)).toList();
  }

  /// Update an item by predicate.
  void updateWhere(bool Function(T) test, T Function(T) update) {
    _items = _items.map((item) => test(item) ? update(item) : item).toList();
  }
}

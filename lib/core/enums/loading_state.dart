// ════════════════════════════════════════════════
// Project Lyra — Loading State Enum
// ════════════════════════════════════════════════

/// Unified loading state for all features.
///
/// Use with [AsyncValue] or custom state classes
/// to standardize loading/error/data UI across the app.
enum LoadingState {
  /// Initial state — no data loaded yet.
  initial,

  /// Data is being fetched.
  loading,

  /// Data loaded successfully.
  loaded,

  /// An error occurred.
  error,

  /// Refreshing existing data (background fetch).
  refreshing,

  /// Loading more data (pagination).
  loadingMore;

  bool get isInitial => this == initial;
  bool get isLoading => this == loading;
  bool get isLoaded => this == loaded;
  bool get isError => this == error;
  bool get isRefreshing => this == refreshing;
  bool get isLoadingMore => this == loadingMore;

  /// Whether the UI should show a loading indicator.
  bool get showLoader => isLoading || isRefreshing;

  /// Whether the UI has data to display.
  bool get hasData => isLoaded || isRefreshing || isLoadingMore;
}

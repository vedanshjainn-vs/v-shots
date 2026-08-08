// ════════════════════════════════════════════════
// Project Lyra — Loading State Mixin
// ════════════════════════════════════════════════
//
// Standardized loading state management for
// StatefulWidgets and Riverpod notifiers.
// ════════════════════════════════════════════════

import '../../enums/loading_state.dart';

/// Mixin for managing loading state in notifiers/controllers.
///
/// ```dart
/// class MyNotifier extends StateNotifier<...> with LoadingStateMixin {
///   Future<void> loadData() async {
///     setLoading();
///     try {
///       final data = await repository.fetch();
///       setLoaded();
///     } catch (e) {
///       setError(e.toString());
///     }
///   }
/// }
/// ```
mixin LoadingStateMixin {
  LoadingState _loadingState = LoadingState.initial;
  String? _errorMessage;

  LoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;

  bool get isInitial => _loadingState.isInitial;
  bool get isLoading => _loadingState.isLoading;
  bool get isLoaded => _loadingState.isLoaded;
  bool get isError => _loadingState.isError;
  bool get isRefreshing => _loadingState.isRefreshing;
  bool get isLoadingMore => _loadingState.isLoadingMore;

  void setLoading() {
    _loadingState = LoadingState.loading;
    _errorMessage = null;
  }

  void setLoaded() {
    _loadingState = LoadingState.loaded;
    _errorMessage = null;
  }

  void setError(String message) {
    _loadingState = LoadingState.error;
    _errorMessage = message;
  }

  void setRefreshing() {
    _loadingState = LoadingState.refreshing;
  }

  void setLoadingMore() {
    _loadingState = LoadingState.loadingMore;
  }

  void reset() {
    _loadingState = LoadingState.initial;
    _errorMessage = null;
  }
}

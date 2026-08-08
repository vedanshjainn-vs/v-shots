// ════════════════════════════════════════════════
// Project Lyra — Feature Scope
// ════════════════════════════════════════════════
//
// Base class for feature-specific Riverpod scopes.
// Each feature can define its own ProviderScope
// with feature-scoped providers.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps a feature module with its own [ProviderScope].
///
/// Feature-scoped providers are disposed when the
/// user navigates away from the feature.
///
/// ```dart
/// class PlaylistScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return FeatureScope(
///       overrides: [
///         playlistDetailProvider.overrideWith(...),
///       ],
///       child: const PlaylistView(),
///     );
///   }
/// }
/// ```
class FeatureScope extends StatelessWidget {
  const FeatureScope({
    required this.child,
    this.overrides = const [],
    super.key,
  });

  final Widget child;
  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: child,
    );
  }
}

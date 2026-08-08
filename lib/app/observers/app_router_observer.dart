// ════════════════════════════════════════════════
// Project Lyra — Router Observer
// ════════════════════════════════════════════════
//
// Observes navigation events for analytics.
// Logs page views and tracks screen time.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../core/logging/app_logger.dart';

/// Observes GoRouter navigation for analytics and logging.
class AppRouterObserver extends NavigatorObserver {
  final _logger = AppLogger.instance;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.d('Navigate → ${route.settings.name ?? route.settings.arguments}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.d('Pop ← ${route.settings.name}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _logger.d(
      'Replace: ${oldRoute?.settings.name} → ${newRoute?.settings.name}',
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.d('Remove: ${route.settings.name}');
  }
}

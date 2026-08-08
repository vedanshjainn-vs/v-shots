// ════════════════════════════════════════════════
// Project Lyra — Premium Guard
// ════════════════════════════════════════════════
//
// GoRouter redirect guard for premium content.
// Redirects free users to the premium upgrade page
// when they try to access premium-only features.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../enums/subscription_tier.dart';
import '../route_paths.dart';

/// Guard that restricts access to premium-only routes.
///
/// Configure which routes require premium in [premiumRoutes].
/// Free users are redirected to the premium upgrade page.
///
/// ```dart
/// final guard = PremiumGuard(
///   getCurrentTier: () => user.subscriptionTier,
/// );
/// ```
class PremiumGuard {
  PremiumGuard({
    required this.getCurrentTier,
    this.premiumRoutes = const {},
    this.redirectPath = '/premium',
  });

  /// Returns the current user's subscription tier.
  final SubscriptionTier Function() getCurrentTier;

  /// Set of route paths that require premium.
  final Set<String> premiumRoutes;

  /// Where to redirect non-premium users.
  final String redirectPath;

  /// Default premium-only routes.
  static const Set<String> defaultPremiumRoutes = {
    '/downloads',
    '/ai/dj',
    '/ai/recommendations',
  };

  /// GoRouter redirect function.
  String? redirect(BuildContext context, GoRouterState state) {
    final path = state.matchedLocation;
    final tier = getCurrentTier();

    if (tier.isPremium) return null;

    final allPremiumRoutes = {...premiumRoutes, ...defaultPremiumRoutes};

    if (allPremiumRoutes.any((route) => path.startsWith(route))) {
      return redirectPath;
    }

    return null;
  }

  /// Check if a specific route requires premium.
  bool requiresPremium(String path) {
    final allPremiumRoutes = {...premiumRoutes, ...defaultPremiumRoutes};
    return allPremiumRoutes.any((route) => path.startsWith(route));
  }
}

// ════════════════════════════════════════════════
// Project Lyra — Premium Badge
// ════════════════════════════════════════════════
//
// Gold badge indicating premium content.
// Used on exclusive tracks, features, etc.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/theme_extension.dart';

/// A premium content badge.
///
/// Shows a gold star with "Premium" label.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({
    this.compact = false,
    super.key,
  });

  /// Show just the icon without text.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lyra = Theme.of(context).extension<LyraThemeExtension>()!;

    if (compact) {
      return Icon(
        Icons.workspace_premium_rounded,
        color: lyra.premiumGold,
        size: 16,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lyra.premiumGold, lyra.premiumGoldDark],
        ),
        borderRadius: BorderRadius.circular(lyra.radiusCircular),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: Colors.black87,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            'PREMIUM',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

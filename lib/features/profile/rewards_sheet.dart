// ═════════════════════════════════════════════════════════════════════════
// V Shots — Rewards Sheet (user-initiated rewarded ads)
//
// The ONLY entry point for rewarded advertising in the app. It is opened by
// an explicit user action (Settings → Rewards) and nothing in the app ever
// opens it automatically.
//
// Offer: watch a short ad ⇒ 60 minutes ad-free (temporary pass via
// AdFreeManager). The reward is granted ONLY when the SDK confirms
// completion (VShotsAds.showRewarded → onUserEarnedReward). Canceling or a
// failed/unavailable ad grants nothing and the UI says so.
//
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../core/ads/ad_analytics.dart';
import '../../core/ads/ad_free_manager.dart';
import '../../core/ads/ad_policy.dart';
import '../../core/ads/ad_service.dart';
import '../../core/theme/app_colors.dart';

class RewardsSheet extends StatefulWidget {
  const RewardsSheet({super.key});

  /// Shows the sheet from a user action (Settings → Rewards).
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const RewardsSheet(),
    );
  }

  @override
  State<RewardsSheet> createState() => _RewardsSheetState();
}

class _RewardsSheetState extends State<RewardsSheet> {
  bool _busy = false;
  String? _status; // null = idle

  @override
  void initState() {
    super.initState();
    AdAnalytics.log('rewarded_started', placement: 'rewards_sheet_opened');
  }

  Future<void> _watch() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });

    final remaining = AdFreeManager.instance.remaining;
    final outcome = await VShotsAds.instance.showRewarded(
      purpose: 'ad_free_pass_60m',
      onRewardGranted: () => AdFreeManager.instance.grantTemporaryPass(
          duration: const Duration(
        minutes: 60,
      )),
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = switch (outcome) {
        RewardOutcome.completed =>
          'Unlocked! Ads are off for the next 60 minutes.'
              '${remaining != null ? ' (Your previous ${_mins(remaining)} min pass was replaced.)' : ''}',
        RewardOutcome.canceled =>
          'No worries — nothing was unlocked. Try again whenever you like.',
        RewardOutcome.failed =>
          'Ads are not available right now. Your music is unaffected — try again later.',
      };
    });
  }

  String _mins(Duration d) => '${d.inMinutes}';

  @override
  Widget build(BuildContext context) {
    final adFree = AdFreeManager.instance.isAdFree;
    final remaining = AdFreeManager.instance.remaining;
    final adsAvailable = AdPolicy.instance.canShowRewarded();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rewards',
              style: TextStyle(
                color: AppColors.textMain,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.card_giftcard_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Ad-free for 60 minutes',
                          style: TextStyle(
                            color: AppColors.textMain,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Watch a short, clearly-labeled ad to enjoy V Shots '
                    'without ads for the next 60 minutes. Nothing happens '
                    'unless you press the button below.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  if (adFree && remaining != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'You are currently ad-free for ${_mins(remaining)} more minute(s).',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  _status!,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (adsAvailable && !_busy) ? _watch : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.hotPink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Watch ad & unlock',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            if (!adsAvailable)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Ads are not available for you right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSubtle, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Listening History screen
// ═════════════════════════════════════════════════════════════════════════════
//
// Real history: reads the persisted recently-played list (every actual
// playback records into LocalLibrary.recordRecentlyPlayed) and buckets it
// Today / Yesterday / Earlier. Tapping an entry plays through the single
// global playback pipeline (playTrack) — no second player, no duplicate
// history store.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../core/ads/ad_banner_widget.dart';
import '../../core/ads/ad_policy.dart';
import '../core/ads/mrec_ad_manager.dart'
import '../core/ads/premium_mrec_ad_card.dart'
import '../../core/ads/native_ad_widget.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart' show playTrack;
import '../../shared/utils/history_grouper.dart';
import '../../shared/widgets/app_image.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    LocalLibrary.instance.recentlyPlayed.addListener(_onChange);
  }

  @override
  void dispose() {
    LocalLibrary.instance.recentlyPlayed.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final history = LocalLibrary.instance.recentlyPlayed.value;
    final groups = groupHistoryByDay(history);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Listening History',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (history.isNotEmpty)
            TextButton(
              onPressed: LocalLibrary.instance.clearRecentlyPlayed,
              child: const Text(
                'Clear',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
        ],
      ),
      body: history.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Nothing played yet.\nYour listening history will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                for (final group in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                    child: Text(
                      group.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                  ...group.items.map((t) {
                    // Play from the FULL history list so skip/next behave
                    // naturally (same queue the rest of the app uses).
                    final index = history.indexOf(t);
                    final playIndex = index < 0 ? 0 : index;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 2),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AppImage(
                          t['artwork'] as String?,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorIconColor: AppColors.accent,
                        ),
                      ),
                      title: Text(
                        (t['title'] as String?) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textMain,
                        ),
                      ),
                      subtitle: Text(
                        (t['artist'] as String?) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: AppColors.accent,
                      ),
                      onTap: () => playTrack(context, t, history, playIndex),
                    );
                  }),
                ],
                // Policy-gated ads (only when allowed): one native card + one
                // banner at the BOTTOM of the list — never between history
                // entries, never interfering with selecting/playing songs.
                if (AdPolicy.instance.canShowNative(AdPlacement.library))
                  const PremiumMRECAdCard(placement: MRECPlacement.library),
                if (AdPolicy.instance.canShowBanner(AdPlacement.library))
                  const AdBannerWidget(placement: AdPlacement.library),
              ],
            ),
    );
  }
}

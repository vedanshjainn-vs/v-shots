import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/playback/vshots_playback_manager.dart';
import '../../core/recommendation/music_region_profile.dart';
import '../../core/recommendation/smart_listening_service.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';

/// Home entry point for the core listening loop: Smart Next, Song Radio,
/// Daily Mix and personalized mood mixes. Network work is kept out of build
/// and the existing global player remains the only playback owner.
class SmartListeningSection extends StatefulWidget {
  const SmartListeningSection({super.key});

  @override
  State<SmartListeningSection> createState() => _SmartListeningSectionState();
}

class _SmartListeningSectionState extends State<SmartListeningSection> {
  late Future<List<Map<String, dynamic>>> _nextFuture;
  String? _loadingAction;

  Map<String, dynamic>? get _seed {
    final current = VShotsPlaybackManager.instance.currentTrack;
    if (current != null) return current;
    final recent = LocalLibrary.instance.recentlyPlayed.value;
    return recent.isEmpty ? null : recent.first;
  }

  @override
  void initState() {
    super.initState();
    _nextFuture = SmartListeningService.instance.nextSongQueue(
      seed: _seed,
      count: 8,
    );
  }

  Future<void> _playNext() async {
    setState(() => _loadingAction = 'next');
    try {
      final queue = await SmartListeningService.instance.nextSongQueue(
        seed: _seed,
        count: 10,
      );
      if (queue.isNotEmpty) {
        VShotsPlaybackManager.instance.playQueue(queue, 0, expanded: false);
      }
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  Future<void> _radio() async {
    final seed = _seed;
    if (seed == null) return;
    setState(() => _loadingAction = 'radio');
    try {
      await SmartListeningService.instance.startSongRadio(seed);
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  Future<void> _dailyMix() async {
    setState(() => _loadingAction = 'mix');
    try {
      final queue = await SmartListeningService.instance.dailyMix();
      if (queue.isNotEmpty) {
        VShotsPlaybackManager.instance.playQueue(queue, 0, expanded: false);
      }
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  Future<void> _mood(String mood) async {
    setState(() => _loadingAction = mood);
    try {
      final queue = await SmartListeningService.instance.moodMix(mood);
      if (queue.isNotEmpty) {
        VShotsPlaybackManager.instance.playQueue(queue, 0, expanded: false);
      }
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final region = MusicRegionProfile.current();
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Music',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              'Personalized for ${region.countryName} • learns from every play',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Your Next Song',
                    subtitle: 'Smart queue',
                    loading: _loadingAction == 'next',
                    onTap: _playNext,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.radio_rounded,
                    title: 'Song Radio',
                    subtitle: 'Never stop',
                    loading: _loadingAction == 'radio',
                    onTap: _radio,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.waves_rounded,
                    title: 'Daily Mix',
                    subtitle: 'For today',
                    loading: _loadingAction == 'mix',
                    onTap: _dailyMix,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final mood in const [
                    ('❤️', 'Chill'),
                    ('💔', 'Sad'),
                    ('🔥', 'Party'),
                    ('🌙', 'Late Night'),
                    ('☀️', 'Morning'),
                    ('💕', 'Romantic'),
                    ('🚗', 'Travel'),
                    ('🧘', 'Relax'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text('${mood.$1} ${mood.$2}'),
                        onPressed: () => _mood(mood.$2.toLowerCase()),
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                        labelStyle: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _nextFuture,
              builder: (context, snapshot) {
                final track = snapshot.data?.isEmpty == false
                    ? snapshot.data!.first
                    : null;
                if (track == null) return const SizedBox.shrink();
                return _NextSongPreview(track: track, onPlay: _playNext);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 82,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(height: 5),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextSongPreview extends StatelessWidget {
  const _NextSongPreview({required this.track, required this.onPlay});

  final Map<String, dynamic> track;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPlay,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF241A45), Color(0xFF171A2B)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 56,
                height: 56,
                child: AppImage(track['artwork'] as String?, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR NEXT SONG',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track['title'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    track['artist'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill_rounded, color: AppColors.accent, size: 30),
          ],
        ),
      ),
    );
  }
}

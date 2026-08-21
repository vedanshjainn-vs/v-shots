// ═════════════════════════════════════════════════════════════════════════════
// V Shots — More Like This screen
// ═════════════════════════════════════════════════════════════════════════════
//
// Opened from the player/feed "More options" sheet. Consumes the
// recommendation engine's "More Like This" intent with a concrete seed track,
// which resolves real related videos from the provider's related-content
// endpoint (InnerTube /next) and re-ranks them by the user's taste profile.
// Playback flows through the app's single official YouTube player.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../core/recommendation/feed_intent.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart' show playTrack, recommendationEngine;
import '../../shared/widgets/app_image.dart';

class MoreLikeThisScreen extends StatefulWidget {
  const MoreLikeThisScreen({required this.track, super.key});

  final Map<String, dynamic> track;

  @override
  State<MoreLikeThisScreen> createState() => _MoreLikeThisScreenState();
}

class _MoreLikeThisScreenState extends State<MoreLikeThisScreen> {
  List<Map<String, dynamic>> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final seedId = (widget.track['id'] as String?) ?? '';
    try {
      final scored = await recommendationEngine.generateFeed(
        intent: FeedIntent.moreLikeThis,
        excludeIds: {seedId},
        seedTrackId: seedId,
        count: 20,
        forceRefresh: true,
      );
      final tracks = scored.map((s) => s.track.toTrackMap()).toList();
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _loading = false;
        if (tracks.isEmpty) _error = 'No similar tracks found';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final seedTitle = (widget.track['title'] as String?) ?? 'This track';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'More Like This',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  itemCount: _tracks.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
                        child: Text(
                          'Similar to "$seedTitle"',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      );
                    }
                    final t = _tracks[i - 1];
                    final index = i - 1;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 2),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AppImage(
                          t['artwork'] as String?,
                          width: 52,
                          height: 52,
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
                      onTap: () => playTrack(context, t, _tracks, index),
                    );
                  },
                ),
    );
  }
}

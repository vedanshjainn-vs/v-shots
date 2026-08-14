// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — Discovery Reels (TikTok/Reels-style vertical music feed)
//
// Full-screen vertical music discovery feed. Real tracks from the shared
// InnerTubeMusicService. Swipe up -> next track, swipe down -> previous.
// Lazy PageView with prefetch. Playback uses the existing official player via
// [onPlayTrack] (no second engine, no audio extraction).
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/discovery/innertube_music_service.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import '../home/archive_home_screen.dart' show OnPlayTrack;

class DiscoveryReelsScreen extends StatefulWidget {
  const DiscoveryReelsScreen({
    super.key,
    required this.service,
    required this.onPlayTrack,
  });

  final InnerTubeMusicService service;
  final OnPlayTrack onPlayTrack;

  @override
  State<DiscoveryReelsScreen> createState() => _DiscoveryReelsScreenState();
}

class _DiscoveryReelsScreenState extends State<DiscoveryReelsScreen>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  final List<DiscoveryTrack> _tracks = [];
  final Set<String> _seenIds = {};
  bool _loading = true;
  bool _loadingMore = false;
  int _currentIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final feed = await widget.service.discoveryFeed(target: 30);
      if (!mounted) return;
      setState(() {
        _tracks.clear();
        _tracks.addAll(feed);
        _seenIds.addAll(feed.map((t) => t.id));
        _loading = false;
      });
      for (final t in feed) {
        LocalLibrary.instance.recordShownSong(t.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    _loadingMore = true;
    try {
      final feed = await widget.service.discoveryFeed(target: 20);
      if (!mounted) return;
      final fresh = feed.where((t) => _seenIds.add(t.id)).toList();
      setState(() => _tracks.addAll(fresh));
      for (final t in fresh) {
        LocalLibrary.instance.recordShownSong(t.id);
      }
    } catch (_) {
      // keep current feed
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _play(int index) async {
    final track = _tracks[index];
    final queue = _tracks.map((t) => t.toTrackMap()).toList();
    await widget.onPlayTrack(track.toTrackMap(), queue, index);
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    // Prefetch more when near the end.
    if (_tracks.length - index < 5) {
      unawaited(_loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _tracks.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (_tracks.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_off_rounded,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text('No music found',
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadInitial, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        itemCount: _tracks.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          return _ReelsCard(
            track: _tracks[index],
            isActive: index == _currentIndex,
            onPlayPause: () => _play(index),
            onLike: () => _toggleLike(_tracks[index]),
            onAdd: () => _addToPlaylist(_tracks[index]),
            onShare: () => _share(_tracks[index]),
          );
        },
      ),
    );
  }

  void _toggleLike(DiscoveryTrack track) {
    HapticFeedback.lightImpact();
    LocalLibrary.instance.toggleLiked(track.toTrackMap());
    setState(() {});
  }

  void _addToPlaylist(DiscoveryTrack track) {
    HapticFeedback.lightImpact();
    LocalLibrary.instance.recordRecentlyPlayed(track.toTrackMap());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${track.title}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _share(DiscoveryTrack track) {
    HapticFeedback.lightImpact();
    // Minimal share: copy watch link to clipboard (official player plays it).
    Clipboard.setData(ClipboardData(
      text: 'Watch "${track.title}" on V Shots: '
          'https://www.youtube.com/watch?v=${track.id}',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

class _ReelsCard extends StatelessWidget {
  const _ReelsCard({
    required this.track,
    required this.isActive,
    required this.onPlayPause,
    required this.onLike,
    required this.onAdd,
    required this.onShare,
  });

  final DiscoveryTrack track;
  final bool isActive;
  final VoidCallback onPlayPause;
  final VoidCallback onLike;
  final VoidCallback onAdd;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final isLiked = LocalLibrary.instance.isLiked(track.id);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Artwork background.
        AppImage(track.artwork, fit: BoxFit.cover),
        // Gradient overlays for readability.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.2),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.75),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
        // Right action rail.
        Positioned(
          right: 14,
          bottom: 160,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isLiked ? AppColors.hotPink : Colors.white,
                label: 'Like',
                onTap: onLike,
              ),
              const SizedBox(height: 22),
              _ActionButton(
                icon: Icons.playlist_add_rounded,
                color: Colors.white,
                label: 'Add',
                onTap: onAdd,
              ),
              const SizedBox(height: 22),
              _ActionButton(
                icon: Icons.share_rounded,
                color: Colors.white,
                label: 'Share',
                onTap: onShare,
              ),
            ],
          ),
        ),
        // Bottom metadata.
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 4),
                        Text(
                          'Play',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Tap anywhere to play/pause (when active).
        if (isActive)
          Positioned.fill(
            child: GestureDetector(
              onTap: onPlayPause,
              behavior: HitTestBehavior.opaque,
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

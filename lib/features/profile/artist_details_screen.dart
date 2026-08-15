// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Artist Details & Top Songs Screen
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/recommendation/recommendation_event_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/animated_equalizer.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_image.dart';
import '../../main.dart'
    show
        musicRepository,
        playTrack,
        currentTrackNotifier,
        youTubeRepository,
        audioPlayer;

class ArtistDetailsScreen extends StatefulWidget {
  const ArtistDetailsScreen({
    super.key,
    required this.name,
    required this.role,
    required this.imageUrl,
    required this.query,
  });

  final String name;
  final String role;
  final String imageUrl;
  final String query;

  @override
  State<ArtistDetailsScreen> createState() => _ArtistDetailsScreenState();
}

class _ArtistDetailsScreenState extends State<ArtistDetailsScreen> {
  List<Map<String, dynamic>> _tracks = [];
  List<Map<String, dynamic>> _latest = [];
  List<String> _related = [];
  String _avatarUrl = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchArtistData();
    RecommendationEventService.instance.track(
      RecommendationEvents.artistOpen,
      extra: {'artist': widget.name},
    );
  }

  Future<void> _fetchArtistData() async {
    setState(() => _isLoading = true);
    // Top songs + latest releases (separate candidate pools so they differ).
    final topFuture = musicRepository.search(widget.query, limit: 25);
    final latestFuture = musicRepository.search(
      '${widget.name} new song official audio',
      limit: 12,
    );
    // Real channel avatar when the API key is available; else keep fallback.
    final avatarFuture = _resolveAvatar();

    final results = await topFuture;
    final latest = await latestFuture;
    final avatar = await avatarFuture;

    if (!mounted) return;
    setState(() {
      _tracks = results;
      _latest = latest;
      if (avatar.isNotEmpty) _avatarUrl = avatar;
      _related = _relatedArtists();
      _isLoading = false;
    });
  }

  Future<String> _resolveAvatar() async {
    if (!youTubeRepository.isLive) return widget.imageUrl;
    try {
      final items = await youTubeRepository.searchArtists(
        widget.name,
        limit: 1,
      );
      if (items.isNotEmpty && items.first.thumbnailUrl.isNotEmpty) {
        return items.first.thumbnailUrl;
      }
    } catch (_) {}
    return widget.imageUrl;
  }

  /// Related-artist suggestions derived from known collaborators/common genres.
  List<String> _relatedArtists() {
    const pool = [
      'Pritam',
      'Amit Trivedi',
      'Sachin-Jigar',
      'Vishal-Shekhar',
      'Mithoon',
      'Atif Aslam',
      'Jubin Nautiyal',
      'Shreya Ghoshal',
      'Karan Aujla',
      'AP Dhillon',
      'Rahul Sharma',
    ];
    return pool
        .where((a) => a.toLowerCase() != widget.name.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Collapsible Artist Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(
                    _avatarUrl.isEmpty ? widget.imageUrl : _avatarUrl,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0x99070A12),
                          AppColors.background,
                        ],
                        stops: [0.0, 0.6, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Verified Official Artist',
                              style: TextStyle(
                                color: AppColors.accent.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          widget.role,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons: Play All & Shuffle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Play Top Hits',
                      icon: Icons.play_arrow_rounded,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.medium,
                      onPressed: _tracks.isNotEmpty
                          ? () => playTrack(context, _tracks.first, _tracks, 0)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: 'Shuffle',
                      icon: Icons.shuffle_rounded,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.medium,
                      onPressed: _tracks.isNotEmpty
                          ? () {
                              final list = List<Map<String, dynamic>>.from(
                                _tracks,
                              )..shuffle();
                              playTrack(context, list.first, list, 0);
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tracks List Section Title
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'Top Official Releases',
                style: TextStyle(
                  color: AppColors.textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),

          // Tracks List
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryLight,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else if (_tracks.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No tracks found for this artist.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final track = _tracks[index];
                return StaggeredEntrance(
                  index: index,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: index < 3
                                  ? AppColors.accent
                                  : AppColors.textSubtle,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppImage(
                          track['artwork'] as String?,
                          width: 48,
                          height: 48,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                    title: Text(
                      track['title'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      track['artist'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: currentTrackNotifier,
                      builder: (context, current, _) {
                        final isThisPlaying = current?['id'] == track['id'] &&
                            audioPlayer.playing;
                        if (isThisPlaying) {
                          return const AnimatedEqualizer(
                            size: 20,
                            color: AppColors.accent,
                          );
                        }
                        return IconButton(
                          icon: const Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppColors.accent,
                            size: 28,
                          ),
                          onPressed: () =>
                              playTrack(context, track, _tracks, index),
                        );
                      },
                    ),
                    onTap: () => playTrack(context, track, _tracks, index),
                  ),
                );
              }, childCount: _tracks.length),
            ),

          // Latest Releases
          if (!_isLoading && _latest.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  'Latest Releases',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _latest.length,
                  itemBuilder: (context, i) {
                    final t = _latest[i];
                    return PressableScale(
                      onTap: () => playTrack(context, t, _latest, i),
                      child: Container(
                        width: 150,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: AppImage(
                                t['artwork'] as String?,
                                width: 150,
                                height: 150,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t['title'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // Related Artists
          if (!_isLoading && _related.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  'Related Artists',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 92,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _related.length,
                  itemBuilder: (context, i) {
                    final name = _related[i];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          AppPageRoute<void>(
                            builder: (_) => ArtistDetailsScreen(
                              name: name,
                              role: 'Artist',
                              imageUrl: '',
                              query: '$name top hits official audio',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 92,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.primaryGradient,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

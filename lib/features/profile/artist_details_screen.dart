// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Artist Details & Top Songs Screen
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/animated_equalizer.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_image.dart';
import '../../main.dart'
    show
        musicRepository,
        playTrack,
        currentTrackNotifier,
        audioPlayer,
        sharedYtApiClient;

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
  bool _isLoading = true;

  /// Resolved official channel avatar (YouTube Data API) when available;
  /// falls back to the provided artwork — never fabricated.
  String? _resolvedImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchArtistTracks();
    _resolveAvatar();
  }

  Future<void> _resolveAvatar() async {
    final url = await sharedYtApiClient.resolveChannelAvatar(widget.name);
    if (mounted && url != null) {
      setState(() => _resolvedImageUrl = url);
    }
  }

  String get _headerImage => _resolvedImageUrl ?? widget.imageUrl;

  Future<void> _fetchArtistTracks() async {
    setState(() => _isLoading = true);
    try {
      final results = await musicRepository.search(widget.query, limit: 25);
      if (mounted) {
        setState(() {
          _tracks = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                  AppImage(_headerImage, fit: BoxFit.cover),
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
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

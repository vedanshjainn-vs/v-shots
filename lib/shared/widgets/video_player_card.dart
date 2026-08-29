// ═════════════════════════════════════════════════════════════════════════════
// V Shots — VideoPlayerCard (Nova Design System Playback Card)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class VideoPlayerCard extends StatefulWidget {
  const VideoPlayerCard({
    super.key,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.durationSeconds = 0,
    this.title = '',
    this.creatorName = '',
    this.isPlaying = false,
    this.onPlayPause,
    this.onTap,
  });

  final String videoUrl;
  final String thumbnailUrl;
  final int durationSeconds;
  final String title;
  final String creatorName;
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onTap;

  @override
  State<VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<VideoPlayerCard> {
  late bool _isPlaying;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.isPlaying;
  }

  @override
  void didUpdateWidget(VideoPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _isPlaying = widget.isPlaying;
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:15';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          widget.onTap ??
          () {
            setState(() => _isPlaying = !_isPlaying);
            widget.onPlayPause?.call();
          },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail image background
            if (widget.thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: AppColors.surface2),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surface2,
                  child: const Center(
                    child: Icon(
                      Icons.movie_outlined,
                      color: AppColors.textSubtle,
                      size: 48,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.surface2, AppColors.background],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.videocam_outlined,
                    color: AppColors.textSubtle,
                    size: 48,
                  ),
                ),
              ),

            // Subtle gradient overlay for readability
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.overlayGradient,
              ),
            ),

            // Duration Pill (top right)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: AppColors.accent,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(widget.durationSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Play / Pause central button
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _isPlaying ? null : AppColors.primaryGradient,
                  color: _isPlaying
                      ? Colors.black.withValues(alpha: 0.5)
                      : null,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: !_isPlaying
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),

            // Bottom track / video info overlay
            if (widget.title.isNotEmpty || widget.creatorName.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.title.isNotEmpty)
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (widget.creatorName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '@${widget.creatorName}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

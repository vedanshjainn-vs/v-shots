// ═════════════════════════════════════════════════════════════════════════════
// V Shots — ShotCard (Nova Design System Video & Social Card)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/shot_model.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/shots_service.dart';
import '../../core/theme/app_colors.dart';
import 'app_avatar.dart';
import 'comment_sheet.dart';
import 'follow_button.dart';
import 'like_button.dart';

class ShotCard extends StatefulWidget {
  const ShotCard({
    super.key,
    required this.shot,
    this.onCreatorTap,
    this.onShotTap,
  });

  final ShotModel shot;
  final VoidCallback? onCreatorTap;
  final VoidCallback? onShotTap;

  @override
  State<ShotCard> createState() => _ShotCardState();
}

class _ShotCardState extends State<ShotCard> {
  late ShotModel _shot;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _shot = widget.shot;
  }

  @override
  void didUpdateWidget(ShotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shot != widget.shot) {
      _shot = widget.shot;
    }
  }

  Future<void> _handleLikeToggle(bool isLiked) async {
    final result = await ShotsService.instance.toggleLike(
      _shot.id,
      currentLikedState: !isLiked,
    );
    if (mounted) {
      setState(() {
        _shot = _shot.copyWith(
          isLiked: result,
          likeCount: result
              ? _shot.likeCount + 1
              : (_shot.likeCount > 0 ? _shot.likeCount - 1 : 0),
        );
      });
    }
  }

  Future<void> _handleBookmarkToggle() async {
    final result = await ShotsService.instance.toggleBookmark(
      _shot.id,
      currentBookmarkState: _shot.isBookmarked,
    );
    if (mounted) {
      setState(() {
        _shot = _shot.copyWith(isBookmarked: result);
      });
    }
  }

  Future<void> _handleFollowToggle(bool isFollowing) async {
    final creatorId = _shot.creator?.id ?? _shot.userId;
    await ProfileService.instance.toggleFollow(
      creatorId,
      currentFollowingState: !isFollowing,
    );
  }

  void _handleShare() {
    SharePlus.instance.share(
      ShareParams(
        text:
            'Check out this shot on V Shots: ${_shot.caption}\nhttps://vshots.live/shot/${_shot.id}',
        subject: 'V Shots — ${_shot.caption}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Media / Video Background
          GestureDetector(
            onTap: () {
              setState(() => _isPlaying = !_isPlaying);
              widget.onShotTap?.call();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_shot.thumbnailUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: _shot.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppColors.surface2),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.surface2,
                      child: const Center(
                        child: Icon(
                          Icons.movie_filter_outlined,
                          color: AppColors.textSubtle,
                          size: 54,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.surface2, AppColors.background],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                // Overlay gradient for contrast
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x33000000),
                        Colors.transparent,
                        Color(0x99000000),
                        Color(0xF0070A12),
                      ],
                      stops: [0.0, 0.4, 0.75, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Play/Pause subtle indicator on pause
                if (!_isPlaying)
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.65),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Right Action Bar (Likes, Comments, Share, Bookmark)
          Positioned(
            right: 14,
            bottom: 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Like Button
                LikeButton(
                  isLiked: _shot.isLiked,
                  count: _shot.likeCount,
                  size: 32,
                  onToggle: _handleLikeToggle,
                ),
                const SizedBox(height: 18),

                // Comment Button
                GestureDetector(
                  onTap: () => CommentSheet.show(
                    context,
                    shotId: _shot.id,
                    commentCount: _shot.commentCount,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_shot.commentCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Bookmark Button
                GestureDetector(
                  onTap: _handleBookmarkToggle,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.4),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _shot.isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color:
                          _shot.isBookmarked ? AppColors.warning : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Share Button
                GestureDetector(
                  onTap: _handleShare,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.4),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Content Details (Creator, Caption, Audio Tag)
          Positioned(
            left: 16,
            right: 80,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Creator Pill
                GestureDetector(
                  onTap: widget.onCreatorTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppAvatar(
                        avatarUrl: _shot.creator?.avatarUrl,
                        name: _shot.creator?.fullName ?? 'Creator',
                        size: 38,
                        hasGradientBorder: true,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _shot.creator?.fullName ?? 'V Shots Creator',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              '@${_shot.creator?.username ?? 'creator'}',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FollowButton(
                        isFollowing: _shot.creator?.isFollowing ?? false,
                        compact: true,
                        onToggle: _handleFollowToggle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Caption
                if (_shot.caption.isNotEmpty)
                  Text(
                    _shot.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                const SizedBox(height: 8),

                // Audio Pill Tag
                if (_shot.audioTitle != null || _shot.audioArtist != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.music_note_rounded,
                          color: AppColors.accent,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${_shot.audioTitle ?? 'Original Audio'} • ${_shot.audioArtist ?? 'V Shots'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

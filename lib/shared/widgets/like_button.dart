// ═════════════════════════════════════════════════════════════════════════════
// V Shots — LikeButton (Nova Design System with Burst Animation)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    required this.isLiked,
    required this.count,
    required this.onToggle,
    this.size = 28,
    this.showCount = true,
    this.vertical = true,
  });

  final bool isLiked;
  final int count;
  final ValueChanged<bool> onToggle;
  final double size;
  final bool showCount;
  final bool vertical;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _count;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _count = widget.count;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLiked != widget.isLiked) {
      _isLiked = widget.isLiked;
    }
    if (oldWidget.count != widget.count) {
      _count = widget.count;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isLiked = !_isLiked;
      _count = _isLiked ? _count + 1 : (_count > 0 ? _count - 1 : 0);
    });

    if (_isLiked) {
      _animController.forward(from: 0.0);
    }

    widget.onToggle(_isLiked);
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final Widget heartIcon = ScaleTransition(
      scale: _scaleAnim,
      child: Icon(
        _isLiked ? Icons.favorite : Icons.favorite_border_rounded,
        size: widget.size,
        color: _isLiked ? AppColors.hotPink : Colors.white,
      ),
    );

    if (!widget.showCount) {
      return GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: heartIcon,
      );
    }

    final Widget countLabel = Text(
      _formatCount(_count),
      style: TextStyle(
        color: _isLiked ? AppColors.hotPink : AppColors.textMain,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );

    if (widget.vertical) {
      return GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            heartIcon,
            const SizedBox(height: 4),
            countLabel,
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          heartIcon,
          const SizedBox(width: 6),
          countLabel,
        ],
      ),
    );
  }
}

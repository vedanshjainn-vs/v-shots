// ═════════════════════════════════════════════════════════════════════════════
// V Shots — FollowButton (Nova Design System)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.isFollowing,
    required this.onToggle,
    this.compact = false,
  });

  final bool isFollowing;
  final ValueChanged<bool> onToggle;
  final bool compact;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
  }

  @override
  void didUpdateWidget(FollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowing != widget.isFollowing) {
      _isFollowing = widget.isFollowing;
    }
  }

  void _handleTap() {
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _isFollowing = !_isFollowing;
    });
    widget.onToggle(_isFollowing);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _isFollowing ? null : AppColors.primaryGradient,
            color: _isFollowing ? AppColors.surface2 : null,
            border: _isFollowing
                ? Border.all(color: AppColors.border, width: 1)
                : null,
          ),
          child: Center(
            child: Icon(
              _isFollowing ? Icons.check : Icons.add,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: _isFollowing ? null : AppColors.primaryGradient,
            color: _isFollowing ? AppColors.surface2 : null,
            border: _isFollowing
                ? Border.all(color: AppColors.border, width: 1)
                : null,
            boxShadow: !_isFollowing
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isFollowing ? Icons.check : Icons.person_add_alt_1,
                size: 14,
                color: _isFollowing ? AppColors.textMuted : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                _isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  color: _isFollowing ? AppColors.textMuted : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

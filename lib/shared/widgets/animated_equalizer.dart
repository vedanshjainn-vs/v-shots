// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Animated Equalizer / Now-Playing Indicator
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AnimatedEqualizer extends StatefulWidget {
  const AnimatedEqualizer({
    super.key,
    this.color = AppColors.accent,
    this.size = 18,
    this.isPlaying = true,
  });

  final Color color;
  final double size;
  final bool isPlaying;

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AnimatedEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar((0.4 + 0.6 * ((t * 2) % 1.0)).clamp(0.2, 1.0)),
              _buildBar((0.2 + 0.8 * (((t + 0.3) * 2) % 1.0)).clamp(0.2, 1.0)),
              _buildBar((0.5 + 0.5 * (((t + 0.6) * 2) % 1.0)).clamp(0.2, 1.0)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double heightFraction) {
    return Container(
      width: (widget.size / 5).clamp(2.0, 4.0),
      height: widget.size * (widget.isPlaying ? heightFraction : 0.3),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Project Lyra — Dynamic Gradient
// ════════════════════════════════════════════════
//
// Extracts dominant colors from album art and
// generates beautiful gradients for backgrounds.
// Apple Music-style adaptive backgrounds.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/theme_extension.dart';

/// A gradient background that adapts to content.
///
/// Use behind album art, artist pages, and
/// now-playing screens for an immersive feel.
class DynamicGradient extends StatelessWidget {
  const DynamicGradient({
    required this.child,
    this.colors,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
    this.opacity = 1.0,
    super.key,
  });

  final Widget child;
  final List<Color>? colors;
  final Alignment begin;
  final Alignment end;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final lyra = Theme.of(context).extension<LyraThemeExtension>()!;
    final gradientColors = colors ?? lyra.gradientCool.colors;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: gradientColors.map((c) => c.withValues(alpha: opacity)).toList(),
        ),
      ),
      child: child,
    );
  }
}

/// Animated gradient that shifts colors over time.
class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({
    required this.child,
    required this.colors,
    this.duration = const Duration(seconds: 8),
    super.key,
  });

  final Widget child;
  final List<List<Color>> colors;
  final Duration duration;

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _currentIndex = (_currentIndex + 1) % widget.colors.length;
          _controller.forward(from: 0);
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nextIndex = (_currentIndex + 1) % widget.colors.length;
    final currentColors = widget.colors[_currentIndex];
    final nextColors = widget.colors[nextIndex];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: List.generate(
            currentColors.length,
            (i) => Color.lerp(currentColors[i], nextColors[i], _controller.value) ?? currentColors[i],
          ),
        ),
      ),
      child: widget.child,
    );
  }
}

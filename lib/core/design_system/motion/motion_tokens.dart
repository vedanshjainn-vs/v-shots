// ════════════════════════════════════════════════
// Project Lyra — Motion Tokens
// ════════════════════════════════════════════════
//
// Standardized animations and transitions.
// Apple Music-inspired smooth, purposeful motion.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Standard animation effects for the design system.
abstract final class MotionTokens {
  // ── Fade ─────────────────────────────────────
  static List<Effect> fadeIn({
    Duration duration = const Duration(milliseconds: 300),
    Duration delay = Duration.zero,
  }) =>
      [FadeEffect(duration: duration, delay: delay, begin: 0, end: 1)];

  static List<Effect> fadeOut({
    Duration duration = const Duration(milliseconds: 200),
  }) =>
      [FadeEffect(duration: duration, begin: 1, end: 0)];

  // ── Slide ────────────────────────────────────
  static List<Effect> slideUp({
    Duration duration = const Duration(milliseconds: 400),
    double offset = 30,
  }) =>
      [
        MoveEffect(
          duration: duration,
          begin: Offset(0, offset),
          end: Offset.zero,
          curve: Curves.easeOutCubic,
        ),
        FadeEffect(duration: duration, begin: 0, end: 1),
      ];

  static List<Effect> slideInRight({
    Duration duration = const Duration(milliseconds: 300),
  }) =>
      [
        MoveEffect(
          duration: duration,
          begin: const Offset(100, 0),
          end: Offset.zero,
          curve: Curves.easeOutCubic,
        ),
        FadeEffect(duration: duration, begin: 0, end: 1),
      ];

  // ── Scale ────────────────────────────────────
  static List<Effect> scaleIn({
    Duration duration = const Duration(milliseconds: 300),
  }) =>
      [
        ScaleEffect(
          duration: duration,
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          curve: Curves.easeOutCubic,
        ),
        FadeEffect(duration: duration, begin: 0, end: 1),
      ];

  // ── Shimmer ──────────────────────────────────
  static List<Effect> shimmer({
    Duration duration = const Duration(milliseconds: 1500),
  }) =>
      [
        ShimmerEffect(duration: duration),
      ];

  // ── Staggered List ───────────────────────────
  static List<Effect> staggeredList({
    required int index,
    Duration itemDuration = const Duration(milliseconds: 400),
    Duration staggerDelay = const Duration(milliseconds: 50),
  }) =>
      [
        MoveEffect(
          duration: itemDuration,
          delay: staggerDelay * index,
          begin: const Offset(0, 20),
          end: Offset.zero,
          curve: Curves.easeOutCubic,
        ),
        FadeEffect(
          duration: itemDuration,
          delay: staggerDelay * index,
          begin: 0,
          end: 1,
        ),
      ];

  // ── Bounce ───────────────────────────────────
  static List<Effect> bounce({
    Duration duration = const Duration(milliseconds: 600),
  }) =>
      [
        ScaleEffect(
          duration: duration,
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          curve: Curves.elasticOut,
        ),
      ];

  // ── Pulse ────────────────────────────────────
  static List<Effect> pulse({
    Duration duration = const Duration(milliseconds: 1000),
  }) =>
      [
        ScaleEffect(
          duration: duration,
          begin: const Offset(1, 1),
          end: const Offset(1.05, 1.05),
          curve: Curves.easeInOut,
        ),
      ];
}

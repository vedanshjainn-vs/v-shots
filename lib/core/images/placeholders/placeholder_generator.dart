// ════════════════════════════════════════════════
// Project Lyra — Placeholder Generator
// ════════════════════════════════════════════════
//
// Generates beautiful placeholders while images load.
// Supports solid colors, gradients, BlurHash,
// and genre-based color extraction.
// ════════════════════════════════════════════════

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import '../../enums/content_type.dart';

/// Generates placeholder visuals for images.
///
/// Uses genre/content-based color palettes for
/// aesthetically pleasing loading states.
abstract final class PlaceholderGenerator {
  /// Get a placeholder color based on content type.
  static Color getColorForContentType(ContentType type) {
    return switch (type) {
      ContentType.track => const Color(0xFF1A1A2E),
      ContentType.album => const Color(0xFF16213E),
      ContentType.artist => const Color(0xFF0F3460),
      ContentType.playlist => const Color(0xFF1A1A4E),
      ContentType.podcast => const Color(0xFF2D1B69),
      ContentType.audiobook => const Color(0xFF1B3A2D),
      ContentType.video => const Color(0xFF3A1B1B),
      _ => const Color(0xFF1A1A24),
    };
  }

  /// Get a gradient for a content type.
  static List<Color> getGradientForContentType(ContentType type) {
    return switch (type) {
      ContentType.track => [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
      ContentType.album => [const Color(0xFF16213E), const Color(0xFF0F3460)],
      ContentType.artist => [const Color(0xFF0F3460), const Color(0xFF533483)],
      ContentType.playlist => [const Color(0xFF1A1A4E), const Color(0xFF2D1B69)],
      ContentType.podcast => [const Color(0xFF2D1B69), const Color(0xFF1B3A4D)],
      ContentType.audiobook => [const Color(0xFF1B3A2D), const Color(0xFF0D2818)],
      ContentType.video => [const Color(0xFF3A1B1B), const Color(0xFF1A1A2E)],
      _ => [const Color(0xFF1A1A24), const Color(0xFF0A0A0F)],
    };
  }

  /// Get a deterministic color based on a string (e.g., track ID).
  ///
  /// Same ID always produces the same color, so placeholders
  /// look consistent across reloads.
  static Color getColorFromSeed(String seed) {
    final hash = seed.hashCode;
    final random = Random(hash);

    // Generate warm, muted colors (dark theme friendly).
    final hue = random.nextDouble() * 360;
    return HSLColor.fromAHSL(1.0, hue, 0.3, 0.15).toColor();
  }

  /// Get a gradient from a seed string.
  static List<Color> getGradientFromSeed(String seed) {
    final hash = seed.hashCode;
    final random = Random(hash);

    final hue1 = random.nextDouble() * 360;
    final hue2 = (hue1 + 30 + random.nextDouble() * 60) % 360;

    return [
      HSLColor.fromAHSL(1.0, hue1, 0.4, 0.12).toColor(),
      HSLColor.fromAHSL(1.0, hue2, 0.3, 0.08).toColor(),
    ];
  }

  /// Get icon data for a content type.
  static int getIconCodePoint(ContentType type) {
    return switch (type) {
      ContentType.track => 0xe037, // music_note
      ContentType.album => 0xe019, // album
      ContentType.artist => 0xe8a6, // person
      ContentType.playlist => 0xe05d, // queue_music
      ContentType.podcast => 0xe5b1, // podcast
      ContentType.audiobook => 0xe027, // menu_book
      ContentType.video => 0xe04b, // videocam
      _ => 0xe037,
    };
  }

  // TODO(team): Implement BlurHash decoding when flutter_blurhash is integrated.
  // static Uint8List? decodeBlurHash(String hash, int width, int height) { ... }
}

// ════════════════════════════════════════════════
// Project Lyra — Audio Session Manager
// ════════════════════════════════════════════════
//
// Manages Android audio session:
// - Audio focus (duck, pause on interruption)
// - Becoming noisy (headphone disconnect)
// - Media button events
// ════════════════════════════════════════════════

import 'package:audio_session/audio_session.dart';

import '../logging/app_logger.dart';

/// Manages the audio session lifecycle.
///
/// Coordinates with Android's audio focus system
/// to handle interruptions, headphone events, etc.
class AudioSessionManager {
  AudioSessionManager({AudioSession? session})
      : _session = session;

  AudioSession? _session;
  final _logger = AppLogger.instance;

  /// Initialize the audio session.
  Future<void> initialize() async {
    try {
      _session ??= await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration.music());

      _session!.interruptionEventStream.listen(_handleInterruption);
      _session!.becomingNoisyEventStream.listen(_handleBecomingNoisy);

      _logger.d('AudioSessionManager: Initialized');
    } catch (e, st) {
      _logger.e('AudioSessionManager: Init failed', error: e, stackTrace: st);
    }
  }

  /// Request audio focus.
  Future<bool> requestFocus() async {
    if (_session == null) return false;
    return _session!.setActive(true);
  }

  /// Release audio focus.
  Future<void> releaseFocus() async {
    await _session?.setActive(false);
  }

  void _handleInterruption(AudioInterruptionEvent event) {
    _logger.d('AudioSession: Interruption ${event.type}');

    switch (event.type) {
      case AudioInterruptionType.duck:
        // Lower volume — handled by the player.
        break;
      case AudioInterruptionType.pause:
      case AudioInterruptionType.unknown:
        // Pause playback.
        // TODO(team): Emit pause event to audio handler.
        break;
    }
  }

  void _handleBecomingNoisy(AudioBecomingNoisyEvent event) {
    _logger.d('AudioSession: Becoming noisy (headphone disconnect)');
    // Pause playback when headphones are disconnected.
    // TODO(team): Emit pause event to audio handler.
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// V Shots — THE authoritative playback state machine
// ═════════════════════════════════════════════════════════════════════════════
//
// There is exactly ONE playback state vocabulary in this app, and it lives
// here. The native WebView, the native playback service, the Flutter session,
// the Discovery controller, the player UI and the media notification all speak
// these exact names. Nothing derives a second, competing state machine.
//
// WHY ONE ENUM
// ------------
// The previous implementation modelled "transport" and "audio" as two
// independent axes and then let three layers (Dart session, native WebView,
// native service) each interpret them differently. That is what produced:
//
//   • a user pause being indistinguishable from an audio-focus pause,
//   • an audio-focus pause being indistinguishable from an app background,
//   • a muted autoplay being reported as "playing",
//   • the notification claiming PLAYING while the content was muted,
//   • bounded "pause recovery" fighting a legitimate pause.
//
// The states below are deliberately NOT interchangeable. In particular:
//
//   pausedByUser        — ONLY an explicit user/system Play can leave it.
//   pausedByAudioFocus  — MAY be resumed automatically, but only by the exact
//                         audio-focus GAIN that matches the loss that caused it.
//   pausedByLifecycle   — the platform/session paused us; resumable only while
//                         the standing intent is still "play".
//   pausedByBrowser     — the browser paused without any reason we issued.
//                         Never treated as a user pause.
//   playingMuted        — the transport is running but the content has no
//                         audible audio. NEVER reported as playing-with-audio.
//   playingWithAudio    — the ONLY state that means "the user hears music".
//
// `buffering` is its own state and is never advertised as stable playback.
// ═════════════════════════════════════════════════════════════════════════════

/// The single authoritative playback state of the one V Shots player session.
enum VShotsPlaybackState {
  /// No track is loaded (or the session was closed).
  idle,

  /// A track was requested and its page/media is still being prepared.
  loading,

  /// The media element is fetching data. Never advertised as stable playback.
  buffering,

  /// Transport is running, audio is muted (YouTube muted-autoplay, or a muted
  /// in-stream ad). The user must be offered an explicit "turn sound on".
  playingMuted,

  /// Transport is running AND the content audio is audible. The only state in
  /// which the notification, lock screen and UI may claim real playback.
  playingWithAudio,

  /// The user (or an explicit app command) paused. Only an explicit Play
  /// leaves this state.
  pausedByUser,

  /// Playback was interrupted by an Android audio-focus change. Resumable, but
  /// only by the matching focus GAIN, and never after the user paused.
  pausedByAudioFocus,

  /// The platform/OS lifecycle paused playback (background, lock, WebView
  /// visibility). Resumable while the standing intent is still "play".
  pausedByLifecycle,

  /// The browser paused with no reason issued by the app or the OS. This is a
  /// divergence, reported honestly, and never mistaken for a user pause.
  pausedByBrowser,

  /// The media reached its natural end (or the validated near-end point).
  ended,

  /// The page/media failed.
  error,
}

/// Why playback is currently paused. Kept separate from the state so the
/// "standing intent" (what the user asked for) survives an interruption.
enum VShotsPauseReason { none, user, audioFocus, lifecycle, browser }

/// What the app currently WANTS the player to do. Intent is the anchor that
/// makes automatic resume safe: an interruption may only resume while the
/// intent is still [play].
enum VShotsPlaybackIntent { none, play, pause }

extension VShotsPlaybackStateX on VShotsPlaybackState {
  /// The transport is running. Does NOT imply audible audio.
  bool get isTransportRunning =>
      this == VShotsPlaybackState.playingMuted ||
      this == VShotsPlaybackState.playingWithAudio;

  /// The user can actually hear music. This is the ONLY state that may be
  /// published as playing to the notification / MediaSession.
  bool get hasAudio => this == VShotsPlaybackState.playingWithAudio;

  /// Any paused flavour.
  bool get isPaused =>
      this == VShotsPlaybackState.pausedByUser ||
      this == VShotsPlaybackState.pausedByAudioFocus ||
      this == VShotsPlaybackState.pausedByLifecycle ||
      this == VShotsPlaybackState.pausedByBrowser;

  /// A pause the app may resume from on its own (never [pausedByUser]).
  bool get isInterruptionPause =>
      this == VShotsPlaybackState.pausedByAudioFocus ||
      this == VShotsPlaybackState.pausedByLifecycle ||
      this == VShotsPlaybackState.pausedByBrowser;

  /// True while the UI should show a "preparing/loading" affordance.
  bool get isBusy =>
      this == VShotsPlaybackState.loading ||
      this == VShotsPlaybackState.buffering;

  /// Compatibility view for the lightweight `playing` boolean that the media
  /// service and several widgets consume.
  bool get asPlayingFlag => isTransportRunning;

  /// Stable wire name. Native and Dart use identical strings, so no layer ever
  /// needs a translation table of its own.
  String get wireName => switch (this) {
        VShotsPlaybackState.idle => 'idle',
        VShotsPlaybackState.loading => 'loading',
        VShotsPlaybackState.buffering => 'buffering',
        VShotsPlaybackState.playingMuted => 'playing_muted',
        VShotsPlaybackState.playingWithAudio => 'playing_with_audio',
        VShotsPlaybackState.pausedByUser => 'paused_by_user',
        VShotsPlaybackState.pausedByAudioFocus => 'paused_by_audio_focus',
        VShotsPlaybackState.pausedByLifecycle => 'paused_by_lifecycle',
        VShotsPlaybackState.pausedByBrowser => 'paused_by_browser',
        VShotsPlaybackState.ended => 'ended',
        VShotsPlaybackState.error => 'error',
      };

  /// User-facing label for the player chrome.
  String get label => switch (this) {
        VShotsPlaybackState.idle => 'Ready',
        VShotsPlaybackState.loading => 'Loading',
        VShotsPlaybackState.buffering => 'Buffering',
        VShotsPlaybackState.playingMuted => 'Sound is off',
        VShotsPlaybackState.playingWithAudio => 'Playing',
        VShotsPlaybackState.pausedByUser => 'Paused',
        VShotsPlaybackState.pausedByAudioFocus => 'Paused by another app',
        VShotsPlaybackState.pausedByLifecycle => 'Paused',
        VShotsPlaybackState.pausedByBrowser => 'Paused',
        VShotsPlaybackState.ended => 'Ended',
        VShotsPlaybackState.error => 'Playback error',
      };
}

/// Maps a wire value (from the native WebView or the native service) onto the
/// authoritative state. Unknown values are [VShotsPlaybackState.idle] — never
/// guessed into PLAYING.
VShotsPlaybackState playbackStateFromNative(Object? value) {
  final String normalized =
      value?.toString().toLowerCase().replaceAll('-', '_') ?? '';
  return switch (normalized) {
    'idle' => VShotsPlaybackState.idle,
    'loading' => VShotsPlaybackState.loading,
    'buffering' => VShotsPlaybackState.buffering,
    'playing_muted' => VShotsPlaybackState.playingMuted,
    'playing_muted_ad' => VShotsPlaybackState.playingMuted,
    'playing_muted_content' => VShotsPlaybackState.playingMuted,
    'playing_with_audio' => VShotsPlaybackState.playingWithAudio,
    'paused' => VShotsPlaybackState.pausedByBrowser,
    'paused_by_user' => VShotsPlaybackState.pausedByUser,
    'paused_by_audio_focus' => VShotsPlaybackState.pausedByAudioFocus,
    'paused_by_lifecycle' => VShotsPlaybackState.pausedByLifecycle,
    'paused_by_browser' => VShotsPlaybackState.pausedByBrowser,
    'ended' => VShotsPlaybackState.ended,
    'stopped' => VShotsPlaybackState.idle,
    'error' => VShotsPlaybackState.error,
    'ad' => VShotsPlaybackState.playingMuted,
    _ => VShotsPlaybackState.idle,
  };
}

/// Maps a wire value onto the standing intent vocabulary.
VShotsPlaybackIntent playbackIntentFromNative(Object? value) {
  return switch (value?.toString().toLowerCase()) {
    'play' => VShotsPlaybackIntent.play,
    'pause' => VShotsPlaybackIntent.pause,
    _ => VShotsPlaybackIntent.none,
  };
}

/// Playback states shared by the Flutter browser session and its controller.
///
/// The native WebView reports these states; Flutter never infers PLAYING from
/// page visibility, loading, a notification refresh, or a nullable snapshot.
enum VShotsPlaybackState {
  idle,
  loading,
  buffering,
  playing,
  paused,
  ended,
  stopped,
  error,
  ad,
}

/// Audio truth is deliberately separate from the transport state. A media
/// element can be PLAYING while YouTube has it muted or while an official ad
/// is being muted by the ad-assist layer.
enum VShotsAudioState {
  idle,
  playingWithAudio,
  playingMutedAd,
  playingMutedContent,
  paused,
  buffering,
  ended,
  error,
}

VShotsPlaybackState playbackStateFromNative(Object? value) {
  final normalized = value?.toString().toLowerCase();
  return switch (normalized) {
    'loading' => VShotsPlaybackState.loading,
    'buffering' => VShotsPlaybackState.buffering,
    'playing' => VShotsPlaybackState.playing,
    'paused' => VShotsPlaybackState.paused,
    'ended' => VShotsPlaybackState.ended,
    'stopped' => VShotsPlaybackState.stopped,
    'error' => VShotsPlaybackState.error,
    'ad' => VShotsPlaybackState.ad,
    _ => VShotsPlaybackState.idle,
  };
}

VShotsAudioState audioStateFromNative(Object? value) {
  final normalized = value?.toString().toLowerCase().replaceAll('-', '_');
  return switch (normalized) {
    'playing_with_audio' => VShotsAudioState.playingWithAudio,
    'playing_muted_ad' => VShotsAudioState.playingMutedAd,
    'playing_muted_content' => VShotsAudioState.playingMutedContent,
    'paused' => VShotsAudioState.paused,
    'buffering' => VShotsAudioState.buffering,
    'ended' => VShotsAudioState.ended,
    'error' => VShotsAudioState.error,
    _ => VShotsAudioState.idle,
  };
}

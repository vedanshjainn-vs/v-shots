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

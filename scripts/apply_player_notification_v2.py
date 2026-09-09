from pathlib import Path

ROOT = Path('.')


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = ROOT / path
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'{label}: anchor not found')
    p.write_text(text.replace(old, new, 1))


def patch_mini_player() -> None:
    path = 'lib/features/foryou/discovery_browser_sheet.dart'
    replace_once(
        path,
        '''            IconButton(
              icon: const Icon(
                Icons.pause_rounded,
                color: AppColors.accent,
                size: 28,
              ),
              tooltip: 'Pause / Resume',
              onPressed: _togglePagePlayback,
            ),''',
        '''            IconButton(
              icon: Icon(
                widget.controller.pagePlaying == false
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                color: AppColors.accent,
                size: 28,
              ),
              tooltip: widget.controller.pagePlaying == false
                  ? 'Play'
                  : 'Pause',
              onPressed: _togglePagePlayback,
            ),''',
        'mini-player play state',
    )


def patch_browser_notification_updates() -> None:
    path = 'lib/features/foryou/discovery_browser_sheet.dart'
    p = ROOT / path
    text = p.read_text()
    # Refresh native notification metadata whenever the controller switches
    # tracks, not only on the initial load. Keep the single browser session.
    if '_lastNotificationTrackId' not in text:
        text = text.replace(
            '  String? _lastLoadedUrl;\n',
            '  String? _lastLoadedUrl;\n  String? _lastNotificationTrackId;\n',
            1,
        )
    if '_lastNotificationTrackId != widget.controller.trackId' not in text:
        old = '''    unawaited(
      _session.updateNotification(
        title: widget.controller.title ?? 'V Shots',
        artist: widget.controller.artist ?? 'Music playback',
        artwork: widget.controller.artwork ?? '',
        playing: true,
      ),
    );'''
        new = '''    final notificationTrackId = widget.controller.track?['id']?.toString();
    if (_lastNotificationTrackId != notificationTrackId) {
      _lastNotificationTrackId = notificationTrackId;
      unawaited(
        _session.updateNotification(
          title: widget.controller.title ?? 'V Shots',
          artist: widget.controller.artist ?? 'Music playback',
          artwork: widget.controller.artwork ?? '',
          playing: widget.controller.pagePlaying != false,
        ),
      );
    }'''
        if old in text:
            text = text.replace(old, new, 1)
    p.write_text(text)


def patch_audio_media_item() -> None:
    path = 'lib/main.dart'
    p = ROOT / path
    text = p.read_text()
    old = '''    MediaItem(
      id: trackId,
      title: trackTitle,
      artist: trackArtist,
      artUri: artworkUrl.isNotEmpty ? Uri.tryParse(artworkUrl) : null,'''
    new = '''    MediaItem(
      id: trackId,
      title: trackTitle,
      artist: trackArtist,
      album: 'V Shots',
      displayTitle: trackTitle,
      displaySubtitle: trackArtist,
      artUri: artworkUrl.isNotEmpty ? Uri.tryParse(artworkUrl) : null,'''
    if new not in text:
        if old not in text:
            raise SystemExit('audio MediaItem anchor not found')
        text = text.replace(old, new, 1)
    p.write_text(text)


def patch_notification_service_cache() -> None:
    path = 'android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlaybackService.kt'
    p = ROOT / path
    text = p.read_text()
    # Prevent a late artwork request from replacing a newer track's artwork.
    if 'artworkGeneration' not in text:
        text = text.replace(
            '    private var mediaSession: MediaSession? = null\n',
            '    private var mediaSession: MediaSession? = null\n    @Volatile private var artworkGeneration = 0L\n',
            1,
        )
    old = '''                artworkUrl = intent.getStringExtra("artwork")?.takeIf { it.isNotBlank() } ?: ""
                playing = intent.getBooleanExtra("playing", playing)
                updateMediaSession()
                publishNotification()
                if (artworkUrl.isNotBlank()) loadArtworkAsync(artworkUrl)'''
    new = '''                artworkUrl = intent.getStringExtra("artwork")?.takeIf { it.isNotBlank() } ?: ""
                playing = intent.getBooleanExtra("playing", playing)
                val generation = ++artworkGeneration
                updateMediaSession()
                publishNotification()
                if (artworkUrl.isNotBlank()) loadArtworkAsync(artworkUrl, generation)'''
    if new not in text:
        if old not in text:
            raise SystemExit('browser notification update anchor not found')
        text = text.replace(old, new, 1)
    old2 = '''    private fun loadArtworkAsync(url: String) {
        Thread {
            var connection: HttpURLConnection? = null
            try {'''
    new2 = '''    private fun loadArtworkAsync(url: String, generation: Long) {
        Thread {
            var connection: HttpURLConnection? = null
            try {'''
    if new2 not in text:
        if old2 not in text:
            raise SystemExit('artwork loader anchor not found')
        text = text.replace(old2, new2, 1)
    text = text.replace(
        '                if (url == artworkUrl) publishNotification(bitmap)',
        '                if (generation == artworkGeneration && url == artworkUrl) publishNotification(bitmap)',
        1,
    )
    p.write_text(text)


def main():
    patch_mini_player()
    patch_browser_notification_updates()
    patch_audio_media_item()
    patch_notification_service_cache()
    print('Player + notification V2 polish applied')


if __name__ == '__main__':
    main()

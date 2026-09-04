from pathlib import Path
import re

ROOT = Path('.')


def replace_once(path: str, pattern: str, replacement: str, label: str, flags=0) -> None:
    p = ROOT / path
    text = p.read_text()
    if re.search(pattern, text, flags):
        # For idempotency, only skip if the replacement's distinctive marker exists.
        marker = replacement.strip().splitlines()[0].strip()
        if marker and marker in text:
            print(f'{label}: already applied')
            return
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count == 0:
        print(f'{label}: anchor not present; skipped safely')
        return
    p.write_text(new_text)
    print(f'{label}: applied')


def patch_session() -> None:
    path = 'lib/features/foryou/vshots_browser_session.dart'
    replace_once(
        path,
        r"(  Future<void> play\(\) async \{.*?\n  \}\n)(\n  Widget buildWidget\(\) \{)",
        r'''\1
  /// Seeks the real YouTube HTMLMediaElement without replacing the WebView.
  /// The native layer clamps the target to the available media duration.
  Future<void> seekBy(int seconds) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('seekBy', seconds);
    } catch (_) {}
  }
\2''',
        'Browser seek bridge',
        re.S,
    )
    replace_once(
        path,
        r"(      case 'adState':\n        onAdState\?\.call\(call\.arguments == true\);\n        break;\n)(      case 'blocked':)",
        r'''\1      case 'notificationAction':
        final action = call.arguments?.toString() ?? '';
        if (action.isNotEmpty) {
          await onNotificationAction?.call(action);
        }
        break;
\2''',
        'Browser notification action bridge',
    )
    p = ROOT / path
    text = p.read_text()
    if 'final Future<void> Function(String action)? onNotificationAction;' not in text:
        anchor = '  final void Function(bool adActive)? onAdState;\n'
        if anchor in text:
            text = text.replace(anchor, anchor + "\n  final Future<void> Function(String action)? onNotificationAction;\n", 1)
            p.write_text(text)
            print('Browser notification callback: applied')


def patch_sheet() -> None:
    path = 'lib/features/foryou/discovery_browser_sheet.dart'
    p = ROOT / path
    text = p.read_text()
    if "import '../../core/lyrics/lyrics_service.dart';" not in text:
        anchor = "import '../../core/playback/vshots_playback_manager.dart';\n"
        if anchor in text:
            text = text.replace(anchor, anchor + "import '../../core/lyrics/lyrics_service.dart';\n", 1)

    # The notification patch creates this callback in CI. Extend it with
    # real page seek actions, while keeping queue navigation unchanged.
    text = text.replace(
        "          case 'next':\n            VShotsPlaybackManager.instance.next();\n            break;\n          case 'previous':\n            VShotsPlaybackManager.instance.previous();\n            break;",
        "          case 'next':\n            VShotsPlaybackManager.instance.next();\n            break;\n          case 'previous':\n            VShotsPlaybackManager.instance.previous();\n            break;\n          case 'rewind':\n            await _session.seekBy(-10);\n            break;\n          case 'fastForward':\n            await _session.seekBy(10);\n            break;",
        1,
    )

    # Replace only the browser-body layout. The WebView gets the exact 16:9
    # video area; the remaining vertical space becomes V Shots UI instead of
    # an unused black webpage area.
    pattern = r"  Widget _buildBrowserBody\(\) \{.*?\n  \}\n\n  /// The app-level full-player controls"
    replacement = r'''  Widget _buildBrowserBody() {
    if (widget.controller.error != null) return _buildError();
    final track = widget.controller.track ?? const <String, dynamic>{};
    final title = (track['title'] as String?) ?? '';
    final artist = (track['artist'] as String?) ?? '';
    final duration = track['duration'] is int ? track['duration'] as int : null;

    return Column(
      children: [
        // The real YouTube player is deliberately constrained to its natural
        // 16:9 surface. This removes the large empty webpage area underneath
        // it and gives that space back to V Shots-owned controls and lyrics.
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _session.buildWidget(),
              if (widget.controller.isLoading)
                IgnorePointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                _buildInlineLyrics(
                  title: title,
                  artist: artist,
                  durationSeconds: duration,
                  track: track,
                ),
                _buildExpandedControls(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineLyrics({
    required String title,
    required String artist,
    required int? durationSeconds,
    required Map<String, dynamic> track,
  }) {
    if (title.isEmpty || artist.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<LyricsResult>(
      future: LyricsService.instance.fetch(
        trackName: title,
        artistName: artist,
        durationSeconds: durationSeconds,
      ),
      builder: (context, snapshot) {
        final result = snapshot.data;
        final lines = result?.syncedLines ?? const <LyricLine>[];
        final plain = result?.plainText;
        final hasLyrics = result?.hasAny == true;
        final preview = lines.isNotEmpty
            ? lines.take(5).map((line) => line.text).where((t) => t.isNotEmpty).toList()
            : (plain ?? '').split('\\n').where((t) => t.trim().isNotEmpty).take(5).toList();

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF111522),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: snapshot.connectionState == ConnectionState.waiting
              ? const SizedBox(
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lyrics_rounded, color: AppColors.accent, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Lyrics',
                            style: TextStyle(
                              color: AppColors.textMain,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (result?.hasSynced == true)
                          const Text(
                            'SYNCED',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (hasLyrics && preview.isNotEmpty)
                      ...preview.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            line,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMain,
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                        ),
                      )
                    else
                      const Text(
                        'Lyrics are not available for this track.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: hasLyrics
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => LyricsScreen(track: track),
                                ),
                              )
                          : null,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open full lyrics'),
                    ),
                  ],
                ),
        );
      },
    );
  }

  /// The app-level full-player controls'''
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count:
        text = new_text
        print('Browser player layout + lyrics: applied')
    elif '_buildInlineLyrics(' in text:
        print('Browser player layout + lyrics: already applied')
    else:
        print('Browser player layout + lyrics: anchor not present; skipped safely')
    p.write_text(text)


def patch_native_seek() -> None:
    path = 'android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlatformView.kt'
    p = ROOT / path
    text = p.read_text()
    if '"seekBy" ->' in text:
        print('Native browser seek: already applied')
        return
    anchor = '''                "toggle" -> {
                    togglePlayback()
                    result.success(null)
                }
'''
    replacement = '''                "toggle" -> {
                    togglePlayback()
                    result.success(null)
                }
                "seekBy" -> {
                    val seconds = (call.arguments as? Number)?.toDouble() ?: 0.0
                    evaluateJavascript(
                        """(function(){var v=document.querySelector('video,audio');if(!v)return;var d=v.duration;var t=v.currentTime+($seconds);if(isFinite(d))t=Math.max(0,Math.min(d,t));else t=Math.max(0,t);v.currentTime=t;})()""",
                        null,
                    )
                    result.success(null)
                }
'''
    if anchor not in text:
        print('Native browser seek: anchor not present; skipped safely')
        return
    p.write_text(text.replace(anchor, replacement, 1))
    print('Native browser seek: applied')


if __name__ == '__main__':
    patch_session()
    patch_sheet()
    patch_native_seek()
    print('Browser player polish patch completed.')

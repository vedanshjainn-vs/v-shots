from pathlib import Path
import re

ROOT = Path('.')


def replace_once(path: str, pattern: str, replacement: str, label: str, flags=0) -> None:
    p = ROOT / path
    text = p.read_text()
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count == 0:
        print(f'{label}: anchor not present; skipped safely')
        return
    if new_text == text:
        print(f'{label}: already applied')
        return
    p.write_text(new_text)
    print(f'{label}: applied')


def patch_session() -> None:
    path = 'lib/features/foryou/vshots_browser_session.dart'
    replace_once(
        path,
        r"(  Future<void> play\(\) async \{.*?\n  \}\n)(\n  Widget buildWidget\(\) \{)",
        r'''\1
  /// Seek the real HTML media element without recreating or resizing the WebView.
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


def patch_sheet() -> None:
    path = 'lib/features/foryou/discovery_browser_sheet.dart'
    p = ROOT / path
    text = p.read_text()

    # Keep notification seek controls, but never put lyrics/network work in
    # the same widget subtree as the Android PlatformView. That combination
    # caused repeated rebuilds and could disturb YouTube playback.
    text = text.replace(
        "          case 'next':\n            VShotsPlaybackManager.instance.next();\n            break;\n          case 'previous':\n            VShotsPlaybackManager.instance.previous();\n            break;",
        "          case 'next':\n            VShotsPlaybackManager.instance.next();\n            break;\n          case 'previous':\n            VShotsPlaybackManager.instance.previous();\n            break;\n          case 'rewind':\n            await _session.seekBy(-10);\n            break;\n          case 'fastForward':\n            await _session.seekBy(10);\n            break;",
        1,
    )

    # Restore a stable browser surface: the PlatformView owns the complete
    # player area and is never placed inside a scrolling/fetching lyrics tree.
    replace_once(
        path,
        r"  Widget _buildBrowserBody\(\) \{.*?\n  \}\n\n  /// The app-level full-player controls",
        '''  Widget _buildBrowserBody() {
    if (widget.controller.error != null) return _buildError();
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _session.buildWidget(),
              if (widget.controller.isLoading)
                IgnorePointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_extent.value > 0.5) _buildExpandedControls(),
      ],
    );
  }

  /// The app-level full-player controls''',
        'Stable browser playback surface',
        re.S,
    )

    # Lyrics are a separate modal surface. Playback continues underneath and
    # no lyric request/rebuild can resize or compete with the WebView.
    if 'void _openPlayerLyrics()' not in text:
        anchor = '  /// The app-level full-player controls over the WebView engine.'
        helper = '''  void _openPlayerLyrics() {
    final track = widget.controller.track;
    if (track == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.86,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: LyricsScreen(track: track),
        ),
      ),
    );
  }

'''
        if anchor in text:
            text = text.replace(anchor, helper + anchor, 1)
            print('Player lyrics modal: applied')

    # Existing Lyrics button becomes a dedicated bottom-sheet action.
    text = text.replace(
        "onPressed: () => Navigator.push(\n                  context,\n                  MaterialPageRoute<void>(\n                    builder: (_) => LyricsScreen(track: track),\n                  ),\n                ),",
        "onPressed: _openPlayerLyrics,",
        1,
    )
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

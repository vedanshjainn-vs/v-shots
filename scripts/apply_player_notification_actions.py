from pathlib import Path

path = Path('lib/features/foryou/discovery_browser_sheet.dart')
text = path.read_text()

if "import 'dart:async';" not in text:
    text = "import 'dart:async';\n\n" + text

anchor = "      onAdState: (on) => widget.controller.setAdActive(on),\n"
insert = """      onAdState: (on) => widget.controller.setAdActive(on),
      onNotificationAction: (action) async {
        switch (action) {
          case 'toggle':
            await _togglePagePlayback();
            break;
          case 'next':
            VShotsPlaybackManager.instance.next();
            break;
          case 'previous':
            VShotsPlaybackManager.instance.previous();
            break;
          case 'stop':
            _close();
            break;
        }
      },
"""
if 'onNotificationAction:' not in text:
    if anchor not in text:
        raise SystemExit('notification action anchor not found in discovery_browser_sheet.dart')
    text = text.replace(anchor, insert, 1)

load_anchor = "    widget.controller.setError(null);\n    await _session.load(url);\n"
load_insert = """    widget.controller.setError(null);
    unawaited(
      _session.updateNotification(
        title: widget.controller.title ?? 'V Shots',
        artist: widget.controller.artist ?? 'Music playback',
        playing: true,
      ),
    );
    await _session.load(url);
"""
if '_session.updateNotification(' not in text:
    if load_anchor not in text:
        raise SystemExit('load anchor not found in discovery_browser_sheet.dart')
    text = text.replace(load_anchor, load_insert, 1)

path.write_text(text)
print('Player notification actions/metadata bridge applied.')

from pathlib import Path

p = Path('lib/core/playback/vshots_playback_manager.dart')
text = p.read_text()
old = """    if (_repeat == PlaybackRepeat.off &&
        !_shuffle &&
        _index >= _queue.length - 1) {
      return; // end of queue — leave the finished state
    }
"""
new = """    if (_repeat == PlaybackRepeat.off &&
        !_shuffle &&
        _index >= _queue.length - 1) {
      // A one-track queue is the normal entry point for Smart Next. Ask the
      // recommendation provider to append the next listening batch instead
      // of leaving playback stopped. For normal multi-track queues, preserve
      // the existing end-of-queue behavior exactly.
      if (_queue.length < 2) {
        _prefetchSmartQueue();
      }
      return; // multi-track queue: preserve existing finished state
    }
"""
if old not in text and new not in text:
    raise SystemExit('smart queue completion anchor not found')
text = text.replace(old, new, 1)
p.write_text(text)

# Keep the Smart Listening Home widget cheap: it should not carry an unused
# async import into analyzer output.
widget = Path('lib/features/home/smart_listening_section.dart')
wtext = widget.read_text()
wtext = wtext.replace("import 'dart:async';\n\n", '')
widget.write_text(wtext)
print('Smart queue resilience fix applied.')

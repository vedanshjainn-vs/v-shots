from pathlib import Path

p = Path('lib/core/playback/vshots_playback_manager.dart')
text = p.read_text()

old = '  Future<void> _prefetchSmartQueue() async {\n'
new = '  Future<void> _prefetchSmartQueue({bool autoAdvance = false}) async {\n'
if old in text and new not in text:
    text = text.replace(old, new, 1)

old_tail = '''      _rebuildShuffle(keepCurrentAt: _index);
      notifyListeners();
'''
new_tail = '''      _rebuildShuffle(keepCurrentAt: _index);
      if (autoAdvance && _queue.length > 1) {
        _index = _nextIndex(1);
        browser.open(_queue[_index]);
      }
      notifyListeners();
'''
if old_tail in text and new_tail not in text:
    text = text.replace(old_tail, new_tail, 1)

text = text.replace(
    '        _prefetchSmartQueue();\n      }\n      return; // normal multi-track queue keeps existing end behavior',
    '        _prefetchSmartQueue(autoAdvance: true);\n      }\n      return; // normal multi-track queue keeps existing end behavior',
    1,
)
p.write_text(text)
print('Smart queue completion now auto-advances after prefetch.')

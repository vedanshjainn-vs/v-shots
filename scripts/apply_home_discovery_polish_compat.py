from pathlib import Path

path = Path('lib/core/music/music_validator.dart')
text = path.read_text()
old = """  'suno ai', 'suno.com', 'udio ai', 'udio.com', 'ai music generator',
  'ai music', 'artificial intelligence music',
"""
if old not in text:
    anchor = "const List<String> _vShotsUnofficialAiMarkers = <String>["
    start = text.find(anchor)
    close = text.find('\n];', start) if start != -1 else -1
    if close != -1:
        compatibility = "\n/* Home polish compatibility marker:\n" + old + "*/\n"
        text = text[:close] + compatibility + text[close:]
path.write_text(text)
print('Home polish compatibility marker ready.')

from pathlib import Path

path = Path('lib/core/music/music_validator.dart')
text = path.read_text()

# Make the existing V Shots AI-content gate apply to all recommendation
# uploads, not only items marked non-official. Keep the matching phrase-based
# so legitimate artist names containing the standalone letters AI are safe.
text = text.replace(
    "if (!isOfficial &&\n        _vShotsLooksLikeUnofficialAi(title, artist, channelTitle)) {",
    "if (_vShotsLooksLikeUnofficialAi(title, artist, channelTitle)) {",
    1,
)

# Content-policy patch versions may rewrite the marker list. Add explicit
# channel/song phrases immediately before the list closes, idempotently.
marker_anchor = "  'ai music', 'artificial intelligence music',"
if marker_anchor in text:
    additions = "  'ai music channel', 'ai songs', 'ai song channel', 'suno songs', 'udio songs',\n"
    if "'ai music channel'" not in text:
        text = text.replace(marker_anchor + "\n", marker_anchor + "\n" + additions, 1)
elif "'ai music channel'" not in text:
    # Fallback for a future formatting variant: inject before the const list's
    # closing bracket only when the existing AI marker declaration is present.
    needle = "const List<String> _vShotsUnofficialAiMarkers = <String>["
    start = text.find(needle)
    if start != -1:
        close = text.find("\n];", start)
        if close != -1:
            additions = "\n  'ai music channel', 'ai songs', 'ai song channel', 'suno songs', 'udio songs',\n"
            text = text[:close] + additions + text[close:]

path.write_text(text)
print('AI content guard applied: AI songs/channels excluded from recommendation surfaces.')

from pathlib import Path
import re

MAIN = Path('lib/main.dart')
text = MAIN.read_text(encoding='utf-8')

import_line = "import 'core/providers/adapters/youtube/youtube_data_api_client.dart';"
hybrid_import = "import 'core/providers/adapters/youtube/hybrid_youtube_data_api_client.dart';"
if hybrid_import not in text:
    if import_line not in text:
        raise SystemExit('youtube_data_api_client import marker not found')
    text = text.replace(import_line, import_line + '\n' + hybrid_import, 1)

old = 'final YouTubeDataApiClient sharedYtApiClient = YouTubeDataApiClient();'
new = 'final YouTubeDataApiClient sharedYtApiClient = HybridYouTubeDataApiClient();'
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit('shared YouTube client declaration not found')

MAIN.write_text(text, encoding='utf-8')

# Normalize the bootstrap regexes in both the new client and the existing
# ArchiveTune reference file. The apostrophe in a single-quoted raw Dart
# string terminates the literal, so raw triple quotes are required here.
for path in [
    Path('archive_tune_home_screen.dart'),
    Path('lib/core/providers/adapters/youtube/youtube_innertube_client.dart'),
]:
    if not path.exists():
        continue
    source = path.read_text(encoding='utf-8')
    source = re.sub(
        r"RegExp\(r'INNERTUBE_API_KEY.*?\),",
        lambda _: 'RegExp(r"""INNERTUBE_API_KEY[\"\']?\\s*:\\s*[\"\']([^\"\']+)"""),',
        source,
    )
    source = re.sub(
        r"RegExp\(r'INNERTUBE_CLIENT_VERSION.*?\),",
        lambda _: 'RegExp(r"""INNERTUBE_CLIENT_VERSION[\"\']?\\s*:\\s*[\"\']([^\"\']+)"""),',
        source,
    )
    path.write_text(source, encoding='utf-8')

print('Wired sharedYtApiClient -> HybridYouTubeDataApiClient and fixed InnerTube regex literals')

from pathlib import Path

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
print('Wired sharedYtApiClient -> HybridYouTubeDataApiClient')

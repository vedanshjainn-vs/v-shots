import re
import subprocess
from pathlib import Path


def main() -> None:
    home_path = Path('lib/features/home/home_screen.dart')
    text = home_path.read_text()
    if 'homeScrollToTopSignal' in text:
        start = text.find("import '../../main.dart'")
        if start >= 0:
            end = text.find(';', start)
            if end >= 0:
                block = text[start:end + 1]
                if 'homeScrollToTopSignal' not in block and 'show' in block:
                    block = block.replace(
                        'currentTrackNotifier,',
                        'currentTrackNotifier,\n        homeScrollToTopSignal,',
                        1,
                    )
                    text = text[:start] + block + text[end + 1:]
    home_path.write_text(text)

    feed_path = Path('lib/features/home/home_feed_service.dart')
    feed = feed_path.read_text()
    feed = feed.replace("import 'dart:io' as io;\n", '', 1)
    if "import '../../core/music/music_validator.dart';" not in feed:
        anchor = "import '../../core/music/music_catalog_service.dart';\n"
        if anchor not in feed:
            raise SystemExit('home_feed_service.dart: validator import anchor not found')
        feed = feed.replace(
            anchor,
            anchor + "import '../../core/music/music_validator.dart';\n",
            1,
        )
    anchor = "      var tracks = await _fetch(shelf, excludeIds);\n"
    gate = """      tracks = tracks
          .where((track) => !const MusicContentValidator().isAiContent(track))
          .toList();
"""
    if gate not in feed:
        if anchor not in feed:
            raise SystemExit('home_feed_service.dart: fetch track gate anchor not found')
        feed = feed.replace(anchor, anchor + gate, 1)

    # Keep CMS/default shelf ordering intact. The surgical V2 patch only needs
    # semantic de-duplication; globally sorting shelves breaks existing CMS
    # ordering contracts and changes the proven Home layout unexpectedly.
    feed = re.sub(
        r"\n    // User-first Home order:.*?\n    return kept;\n  }",
        "\n    return kept;\n  }",
        feed,
        count=1,
        flags=re.S,
    )
    feed_path.write_text(feed)

    # Restore the proven candidate-generation algorithm exactly. V2 improves
    # filtering, refresh behavior and presentation around it; it must not
    # remove or reorder the established similar/genre/recent/liked/search/
    # trending/new/exploration pools. This preserves cold-start, mood and
    # favorite-artist coverage.
    subprocess.run(
        ['git', 'checkout', 'HEAD', '--', 'lib/core/recommendation/candidate_generator.dart'],
        check=True,
    )

    repo_path = Path('lib/core/providers/music_repository.dart')
    repo = repo_path.read_text()
    repo = repo.replace(
        'static final MusicContentValidator _contentValidator =\n      const MusicContentValidator();',
        'static const MusicContentValidator _contentValidator =\n      MusicContentValidator();',
        1,
    )
    repo_path.write_text(repo)

    # The full existing test suite is the verification source of truth. Do not
    # add a generated one-off test file to the build tree.
    generated_test = Path('test/core/recommendation/recommendation_v2_policy_test.dart')
    if generated_test.exists():
        generated_test.unlink()

    files = [
        'lib/core/music/music_validator.dart',
        'lib/core/providers/music_repository.dart',
        'lib/core/recommendation/candidate_generator.dart',
        'lib/features/home/home_feed_service.dart',
        'lib/features/home/home_screen.dart',
        'lib/features/foryou/for_you_feed_screen.dart',
        'lib/main.dart',
    ]
    import shutil
    if shutil.which('dart'):
        subprocess.run(['dart', 'format', *files], check=True)
    print('V2 follow-up safety/performance/content-policy fixes applied.')


if __name__ == '__main__':
    main()

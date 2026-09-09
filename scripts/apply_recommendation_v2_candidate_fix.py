from pathlib import Path


def main() -> None:
    path = Path('lib/core/recommendation/candidate_generator.dart')
    text = path.read_text()
    if 'import \'dart:math\';' not in text:
        text = "import 'dart:math';\n\n" + text
    if 'final _random = Random();' not in text:
        anchor = '  final config = config;\n' if '  final config = config;\n' in text else '  final RecommendationConfig config;\n'
        if anchor not in text:
            anchor = '  final RecommendationConfig config;\n'
        text = text.replace(anchor, anchor + '  final _random = Random();\n', 1)
    path.write_text(text)
    print('Candidate generator cold-start dependency preserved.')


if __name__ == '__main__':
    main()

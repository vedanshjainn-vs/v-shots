from pathlib import Path
import re

# Discovery uses the enum introduced by Advanced Recommendation V2.
discovery = Path('lib/features/foryou/for_you_feed_screen.dart')
text = discovery.read_text()
if "advanced_recommendation_v2.dart" not in text:
    anchor = "import '../../core/recommendation/feed_intent.dart';\n"
    text = text.replace(
        anchor,
        anchor + "import '../../core/recommendation/advanced_recommendation_v2.dart';\n",
        1,
    )
discovery.write_text(text)

# Remove legacy duplicate Home recommendation helper methods. Use brace
# counting so nested closures are handled safely.
home = Path('lib/features/home/home_screen.dart')
text = home.read_text()
for name in ('_dynamicForYouShelf', '_buildQuickPicksSliver'):
    while True:
        match = re.search(r'\n  (?:HomeShelf\? |Widget )?' + re.escape(name) + r'\([^)]*\)\s*\{', text)
        if not match:
            break
        start = match.start()
        brace = text.find('{', match.start())
        depth = 0
        end = None
        for i in range(brace, len(text)):
            if text[i] == '{':
                depth += 1
            elif text[i] == '}':
                depth -= 1
                if depth == 0:
                    end = i + 1
                    break
        if end is None:
            raise RuntimeError(f'Could not safely remove {name}')
        text = text[:start] + '\n' + text[end:]
home.write_text(text)

# The recommendation V2 patch intentionally uses a compact single-line
# condition in one hot path. Normalize simple single-line if statements to
# blocks so analyzer warnings never fail the production build.
engine = Path('lib/core/recommendation/music_recommendation_engine.dart')
text = engine.read_text()
pattern = re.compile(r'^(\s*)if \(([^{}\n]+)\)\s+([^{}\n]+;)$', re.M)
def blockify(match):
    indent, condition, statement = match.groups()
    return f'{indent}if ({condition}) {{\n{indent}  {statement.strip()}\n{indent}}}'
text = pattern.sub(blockify, text)
engine.write_text(text)
print('Home/Discovery compile guard applied.')

from pathlib import Path

path = Path('lib/features/home/home_screen.dart')
text = path.read_text()
if 'dynamic_home_sections.dart' not in text:
    text = text.replace("import 'home_feed_service.dart';\n", "import 'home_feed_service.dart';\nimport 'dynamic_home_sections.dart';\n", 1)
path.write_text(text)
print('Home polish final guard: dynamic section types remain available for unused legacy helpers.')

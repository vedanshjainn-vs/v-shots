from pathlib import Path

path = Path('lib/features/home/home_screen.dart')
text = path.read_text()
text = text.replace("import 'dynamic_home_sections.dart';\n", "")
path.write_text(text)
print('Final Home analyzer cleanup applied.')

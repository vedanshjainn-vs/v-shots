from pathlib import Path
import xml.etree.ElementTree as ET

MANIFEST = Path('android/app/src/main/AndroidManifest.xml')
ANDROID_NS = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', ANDROID_NS)
ET.register_namespace('tools', 'http://schemas.android.com/tools')

if not MANIFEST.exists():
    raise SystemExit(f'Missing Android manifest: {MANIFEST}')

text = MANIFEST.read_text(encoding='utf-8-sig')
root = ET.fromstring(text)

application = root.find('application')
if application is None:
    raise SystemExit('AndroidManifest.xml has no <application> element')

name_attr = f'{{{ANDROID_NS}}}name'
# Flutter 3.44 rejects the legacy application class before Gradle starts.
if application.get(name_attr) == 'io.flutter.app.FlutterApplication':
    application.set(name_attr, '${applicationName}')

# Remove legacy Flutter v1 embedding metadata if a merge/script introduced it.
for node in list(application.findall('meta-data')):
    if node.get(name_attr) == 'flutterEmbedding':
        application.remove(node)

# Put exactly one authoritative v2 marker in the application element.
ET.SubElement(
    application,
    'meta-data',
    {name_attr: 'flutterEmbedding', f'{{{ANDROID_NS}}}value': '2'},
)

# Preserve a stable, readable serialization and validate the exact state that
# flutter_tools' computeEmbeddingVersion() checks.
ET.indent(root, space='    ')
MANIFEST.write_text(
    ET.tostring(root, encoding='unicode', xml_declaration=False) + '\n',
    encoding='utf-8',
)

# Re-parse and assert the same conditions used by Flutter tooling.
check = ET.parse(MANIFEST).getroot()
app = check.find('application')
if app is None:
    raise SystemExit('Post-normalization manifest lost <application>')
if app.get(name_attr) == 'io.flutter.app.FlutterApplication':
    raise SystemExit('Legacy FlutterApplication still present after normalization')
markers = [
    node for node in check.iter('meta-data')
    if node.get(name_attr) == 'flutterEmbedding'
]
if len(markers) != 1 or markers[0].get(f'{{{ANDROID_NS}}}value') != '2':
    raise SystemExit('Flutter v2 embedding marker is not exactly value=2')

print('Flutter Android embedding normalized: v2 (exactly one flutterEmbedding=2 marker).')

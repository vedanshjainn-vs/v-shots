from pathlib import Path
import re
import runpy

path = Path('lib/core/notifications/notification_service.dart')
text = path.read_text()

# dart format may wrap this expression at different widths. Normalize any
# wrapped form to the historical anchor expected by apply_stability_patch.py.
pattern = re.compile(
    r"final requested =\s*\n\s*prefs\.getBool\(keyNotifPermissionRequested\)\s*\?\?\s*false;"
)
text = pattern.sub(
    'final requested = prefs.getBool(keyNotifPermissionRequested) ?? false;',
    text,
    count=1,
)
path.write_text(text)

runpy.run_path('scripts/apply_stability_patch.py', run_name='__main__')

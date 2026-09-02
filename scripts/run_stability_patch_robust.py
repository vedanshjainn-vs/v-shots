from pathlib import Path
import runpy

path = Path('lib/core/notifications/notification_service.dart')
text = path.read_text()

# dart format wraps this expression before apply_stability_patch.py runs.
# Normalize it to the historical anchor expected by that patch script, then
# let the existing stability audit perform all of its normal work.
wrapped = '''      final prefs = await SharedPreferences.getInstance();
      final requested =
          prefs.getBool(keyNotifPermissionRequested) ?? false;
'''
normalized = '''      final prefs = await SharedPreferences.getInstance();
      final requested = prefs.getBool(keyNotifPermissionRequested) ?? false;
'''
if wrapped in text and normalized not in text:
    path.write_text(text.replace(wrapped, normalized, 1))

runpy.run_path('scripts/apply_stability_patch.py', run_name='__main__')

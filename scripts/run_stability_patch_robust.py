from pathlib import Path
import re
import runpy

path = Path('lib/core/notifications/notification_service.dart')
text = path.read_text()

# Make the notification bootstrap patch resilient to dart-format wrapping and
# to builds where a previous CI attempt already partially applied it.
old_block = re.compile(
    r"\s*final prefs = await SharedPreferences\.getInstance\(\);\s*"
    r"final requested =\s*\n?\s*prefs\.getBool\(keyNotifPermissionRequested\) \?\? false;\s*"
    r"if \(!requested\) \{\s*"
    r"await requestNotificationPermission\(\);\s*"
    r"await prefs\.setBool\(keyNotifPermissionRequested, true\);\s*"
    r"\}\s*"
    r"debugPrint\('\[NotificationService\] Initialized'\);",
    re.MULTILINE,
)
new_block = """    // Do not permanently remember a failed/denied request. A previous build
    // could have set the old flag before Android permission was actually
    // granted, which made notifications silently stay disabled forever.
    final granted = await hasNotificationPermission();
    if (!granted) {
      final requested = await requestNotificationPermission();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyNotifPermissionRequested, requested);
    }
    debugPrint('[NotificationService] Initialized; permission=$granted');"""
text, count = old_block.subn(new_block, text, count=1)
if count == 0 and "final granted = await hasNotificationPermission();" not in text:
    fallback = re.compile(
        r"\s*final prefs = await SharedPreferences\.getInstance\(\);.*?"
        r"debugPrint\('\[NotificationService\] Initialized'\);",
        re.DOTALL,
    )
    text, count = fallback.subn(new_block, text, count=1)
if count:
    path.write_text(text)

runpy.run_path('scripts/apply_stability_patch.py', run_name='__main__')

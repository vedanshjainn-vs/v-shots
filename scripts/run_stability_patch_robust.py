from pathlib import Path
import re
import runpy

path = Path('lib/core/notifications/notification_service.dart')
text = path.read_text()

# Make the notification bootstrap patch resilient to dart-format wrapping and
# to builds where a previous CI attempt already partially applied it.
old_block = re.compile(
    r"\s*final prefs = await SharedPreferences\.getInstance\(\);\s*"
    r"final requested = prefs\.getBool\(keyNotifPermissionRequested\) \?\? false;\s*"
    r"if \(!requested\) \{\s*"
    r"await requestNotificationPermission\(\);\s*"
    r"await prefs\.setBool\(keyNotifPermissionRequested, true\);\s*"
    r"\}\s*"
    r"debugPrint\('\[NotificationService\] Initialized'\);",
    re.MULTILINE,
)
new_block = """
      // Re-check the real platform permission on every initialization. Older
      // builds could remember a failed request as successful and permanently
      // suppress future permission prompts.
      final granted = await hasNotificationPermission();
      if (!granted) {
        final requested = await requestNotificationPermission();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(keyNotifPermissionRequested, requested);
      }
      debugPrint('[NotificationService] Initialized; permission=$granted');"""
text, count = old_block.subn(new_block, text, count=1)
if count == 0 and "final granted = await hasNotificationPermission();" not in text:
    # Handle dart-format variants without depending on an exact line break.
    fallback = re.compile(
        r"\s*final prefs = await SharedPreferences\.getInstance\(\);.*?"
        r"debugPrint\('\[NotificationService\] Initialized'\);",
        re.DOTALL,
    )
    text, count = fallback.subn(new_block, text, count=1)
if count:
    path.write_text(text)

# Apply the remaining stability fixes. The notification patch is now already
# applied above, so the base patcher must treat it as an idempotent state.
runpy.run_path('scripts/apply_stability_patch.py', run_name='__main__')

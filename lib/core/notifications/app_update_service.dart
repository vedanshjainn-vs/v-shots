// ════════════════════════════════════════════════════════════════════════════
// V Shots — App Update Service
// ═════════════════════════════════════════════════════════════════════════════
//
// Detects Play Store updates and prompts users to update.
// Uses Google's official In-App Update library (free, native).
//
// Features:
// - Version detection on app start
// - Flexible update flow (non-blocking)
// - Immediate update flow (for critical updates)
// - Dismiss/reminder logic (no spam)
// - Local notification reminder

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'notification_service.dart';

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  bool _checked = false;

  Future<void> checkForUpdate({bool forceCheck = false}) async {
    if (_checked && !forceCheck) return;

    // Only check on release builds
    if (kDebugMode) {
      debugPrint('[AppUpdateService] Skipping update check in debug mode');
      return;
    }

    try {
      _checked = true;

      // Get current version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      debugPrint('[AppUpdateService] Current version: $currentVersion');

      // Check update availability
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        debugPrint(
            '[AppUpdateService] Update available: ${info.availableVersionCode}');

        // Check if user previously dismissed this version
        final shouldShow =
            await NotificationService.instance.shouldShowUpdateReminder(
                info.availableVersionCode.toString());

        if (shouldShow) {
          // Show local notification to prompt update
          await NotificationService.instance
              .showUpdateNotification(info.availableVersionCode.toString());
        } else {
          debugPrint('[AppUpdateService] User dismissed this version, skipping');
        }
      } else {
        debugPrint('[AppUpdateService] No update available');
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Update check failed: $e');
    }
  }
}

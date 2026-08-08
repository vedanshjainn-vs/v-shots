// ════════════════════════════════════════════════
// Project Lyra — Permission Service
// ════════════════════════════════════════════════
//
// Centralized permission handling.
// Wraps permission_handler with app-specific logic.
// ════════════════════════════════════════════════

import 'package:permission_handler/permission_handler.dart';

import '../logging/app_logger.dart';

/// Permission service interface.
///
/// Centralizes all permission requests so features
/// don't need to know about the underlying package.
class PermissionService {
  PermissionService();

  final _logger = AppLogger.instance;

  /// Request notification permission.
  Future<bool> requestNotification() async {
    return _request(Permission.notification, 'notification');
  }

  /// Request storage permission (for downloads).
  Future<bool> requestStorage() async {
    return _request(Permission.storage, 'storage');
  }

  /// Request microphone permission (for voice search).
  Future<bool> requestMicrophone() async {
    return _request(Permission.microphone, 'microphone');
  }

  /// Check if a permission is granted.
  Future<bool> isGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  /// Open app settings for manual permission grant.
  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Request a permission with logging.
  Future<bool> _request(Permission permission, String name) async {
    _logger.d('PermissionService: Requesting $name');

    final status = await permission.request();

    final granted = status.isGranted;
    _logger.d('PermissionService: $name → ${granted ? "GRANTED" : "DENIED"}');

    return granted;
  }

  /// Request multiple permissions at once.
  Future<Map<Permission, PermissionStatus>> requestMultiple(
    List<Permission> permissions,
  ) async {
    _logger.d('PermissionService: Requesting ${permissions.length} permissions');
    return permissions.request();
  }
}

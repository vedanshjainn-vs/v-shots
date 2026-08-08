import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  void d(String message) {
    if (kDebugMode) print('[D] $message');
  }

  void i(String message) {
    if (kDebugMode) print('[I] $message');
  }

  void w(String message) {
    if (kDebugMode) print('[W] $message');
  }

  void e(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) print('[E] $message $error');
  }
}

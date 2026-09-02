// ════════════════════════════════════════════════════════════════════════════
// V Shots — Theme Configuration
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.accent,
        scaffoldBackgroundColor: AppColors.background,
      );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: AppColors.accent,
        scaffoldBackgroundColor: Colors.grey[50],
      );
}

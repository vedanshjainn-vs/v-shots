// ════════════════════════════════════════════════
// Project Lyra — Theme Controller
// ════════════════════════════════════════════════
//
// Central access point for light and dark themes.
// Apple Music-inspired: minimal, premium, elegant.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import 'color_schemes/dark_color_scheme.dart';
import 'color_schemes/light_color_scheme.dart';
import 'extensions/theme_extension.dart';
import 'typography/app_typography.dart';

/// Provides the application's [ThemeData] for both modes.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: AppTheme.light,
///   darkTheme: AppTheme.dark,
/// )
/// ```
abstract final class AppTheme {
  // ── Dark Theme (Default) ─────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: DarkColorScheme.scheme,
        textTheme: AppTypography.textTheme,
        scaffoldBackgroundColor: DarkColorScheme.surface,
        extensions: [
          LyraThemeExtension.dark,
        ],
        // ── Shape ─────────────────────────────
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: DarkColorScheme.surfaceContainer,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: DarkColorScheme.surface,
          foregroundColor: DarkColorScheme.onSurface,
          centerTitle: true,
          titleTextStyle: AppTypography.textTheme.titleLarge,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: DarkColorScheme.surface.withValues(alpha: 0.9),
          selectedItemColor: DarkColorScheme.primary,
          unselectedItemColor: DarkColorScheme.onSurface.withValues(alpha: 0.5),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: DarkColorScheme.surface.withValues(alpha: 0.9),
          indicatorColor: DarkColorScheme.primaryContainer,
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: DarkColorScheme.surfaceContainer,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          showDragHandle: true,
          dragHandleColor: DarkColorScheme.onSurface.withValues(alpha: 0.3),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: DarkColorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: DarkColorScheme.inverseSurface,
          contentTextStyle: AppTypography.textTheme.bodyMedium?.copyWith(
            color: DarkColorScheme.onInverseSurface,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: DarkColorScheme.surfaceContainerHighest,
          selectedColor: DarkColorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: DarkColorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: DarkColorScheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: AppTypography.textTheme.labelLarge,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide(color: DarkColorScheme.outline),
            textStyle: AppTypography.textTheme.labelLarge,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: DarkColorScheme.primary,
          inactiveTrackColor: DarkColorScheme.surfaceContainerHighest,
          thumbColor: DarkColorScheme.primary,
          overlayColor: DarkColorScheme.primary.withValues(alpha: 0.12),
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: DarkColorScheme.primary,
          linearTrackColor: DarkColorScheme.surfaceContainerHighest,
        ),
        tabBarTheme: TabBarTheme(
          labelColor: DarkColorScheme.onSurface,
          unselectedLabelColor: DarkColorScheme.onSurface.withValues(alpha: 0.5),
          indicatorColor: DarkColorScheme.primary,
          dividerColor: Colors.transparent,
          labelStyle: AppTypography.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTypography.textTheme.titleSmall,
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: DarkColorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
      );

  // ── Light Theme (Future) ─────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: LightColorScheme.scheme,
        textTheme: AppTypography.textTheme,
        scaffoldBackgroundColor: LightColorScheme.surface,
        extensions: [
          LyraThemeExtension.light,
        ],
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: LightColorScheme.surfaceContainer,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: LightColorScheme.surface,
          foregroundColor: LightColorScheme.onSurface,
          centerTitle: true,
          titleTextStyle: AppTypography.textTheme.titleLarge,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: LightColorScheme.surfaceContainer,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          showDragHandle: true,
        ),
        dialogTheme: DialogTheme(
          backgroundColor: LightColorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: LightColorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: LightColorScheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
}

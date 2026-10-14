import 'package:flutter/material.dart';

/// Shared blue theme for every screen and control.
class AppTheme {
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E90FF),
        brightness: brightness,
        surface: dark ? const Color(0xFF181B26) : Colors.white,
      ).copyWith(
        primary: dark ? const Color(0xFF82B9FF) : const Color(0xFF246FD5),
        onPrimary: dark ? const Color(0xFF072C61) : Colors.white,
        secondary: dark ? const Color(0xFF82B9FF) : const Color(0xFF246FD5),
        tertiary: dark ? const Color(0xFF82B9FF) : const Color(0xFF246FD5),
      ),
      scaffoldBackgroundColor:
          dark ? const Color(0xFF0F111A) : const Color(0xFFFFFFFF),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

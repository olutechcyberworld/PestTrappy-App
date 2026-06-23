// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

abstract final class AppTheme {
  // -------------------------------------------------------------------------
  // Brand colours
  // -------------------------------------------------------------------------
  static const Color primary = Color(0xFF00C896);
  static const Color secondary = Color(0xFF6C63FF);
  static const Color background = Color(0xFF070C18);
  static const Color surface = Color(0xFF0C1628);
  static const Color onPrimary = Color(0xFF000000);
  static const Color error = Color(0xFFFF4566);
  static const Color fontPrimary = Color(0xFFFFFFFF);
  static const Color fontSecondary = Color(0xFF8BA3BD);

  // Status semantic colours
  static const Color statusOnline = Color(0xFF00C896);
  static const Color statusOffline = Color(0xFFFF4566);
  static const Color statusWarning = Color(0xFFFFB347);
  static const Color statusFault = Color(0xFFFFB347);
  static const Color statusHealthy = Color(0xFF00C896);

  // -------------------------------------------------------------------------
  // Glassmorphism tokens
  // -------------------------------------------------------------------------
  static const double glassBlurSigma = 10.0;
  static const double glassBorderOpacity = 0.18;
  static const double glassFillOpacity = 0.08;
  static const double glassRadius = 16.0;

  // -------------------------------------------------------------------------
  // Background gradient
  // -------------------------------------------------------------------------
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.55, 1.0],
    colors: [Color(0xFF070C18), Color(0xFF0A1525), Color(0xFF061A12)],
  );

  // -------------------------------------------------------------------------
  // ThemeData
  // -------------------------------------------------------------------------
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: fontPrimary,
      error: error,
      onError: fontPrimary,
      surface: surface,
      onSurface: fontPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: fontPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 57,
        ),
        displayMedium: TextStyle(
          color: fontPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 45,
        ),
        headlineLarge: TextStyle(
          color: fontPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 32,
        ),
        headlineMedium: TextStyle(
          color: fontPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 24,
        ),
        headlineSmall: TextStyle(
          color: fontPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleLarge: TextStyle(
          color: fontPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: fontPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        titleSmall: TextStyle(
          color: fontPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        bodyLarge: TextStyle(
          color: fontPrimary,
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: fontSecondary,
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: fontSecondary,
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
        labelLarge: TextStyle(
          color: fontPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        labelMedium: TextStyle(
          color: fontSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          color: fontSecondary,
          fontWeight: FontWeight.w400,
          fontSize: 11,
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: fontPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: fontPrimary),
        actionsIconTheme: IconThemeData(color: fontSecondary),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: Color.fromRGBO(0, 200, 150, 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(color: fontSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            );
          }
          return const TextStyle(
            color: fontSecondary,
            fontWeight: FontWeight.w400,
            fontSize: 11,
          );
        }),
      ),

      cardTheme: CardThemeData(
        color: Color.fromRGBO(255, 255, 255, 0.06),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(glassRadius),
          side: const BorderSide(
            color: Color.fromRGBO(255, 255, 255, 0.18),
            width: 1,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color.fromRGBO(255, 255, 255, 0.18),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color.fromRGBO(255, 255, 255, 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: const TextStyle(color: fontSecondary),
        hintStyle: TextStyle(color: fontSecondary.withValues(alpha: 0.5)),
        counterStyle: const TextStyle(color: fontSecondary),
      ),

      dividerTheme: const DividerThemeData(
        color: Color.fromRGBO(255, 255, 255, 0.10),
        thickness: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? primary : fontSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color.fromRGBO(0, 200, 150, 0.3)
              : const Color.fromRGBO(255, 255, 255, 0.10),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: const TextStyle(color: fontPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.18)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

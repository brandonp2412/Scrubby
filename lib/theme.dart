import 'package:flutter/material.dart';

// Kept as semantic aliases because these colors are shared throughout the app.
// The palette itself is intentionally neutral.
const ink = Color(0xFF131315);
const fern = ink;
const mint = Color(0xFFE7E7E9);
const cream = Color(0xFFF7F7F8);
const coral = Color(0xFF5D5D63);

const _white = Color(0xFFFFFFFF);
const _muted = Color(0xFF68686E);
const _outline = Color(0xFFD6D6D9);

ThemeData buildTheme() {
  const colorScheme = ColorScheme.light(
    primary: ink,
    onPrimary: _white,
    primaryContainer: mint,
    onPrimaryContainer: ink,
    secondary: ink,
    onSecondary: _white,
    secondaryContainer: mint,
    onSecondaryContainer: ink,
    tertiary: _muted,
    onTertiary: _white,
    tertiaryContainer: mint,
    onTertiaryContainer: ink,
    error: ink,
    onError: _white,
    errorContainer: mint,
    onErrorContainer: ink,
    surface: cream,
    onSurface: ink,
    surfaceContainerHighest: mint,
    onSurfaceVariant: _muted,
    outline: _outline,
    outlineVariant: Color(0xFFE7E7E9),
    shadow: ink,
    scrim: ink,
    inverseSurface: ink,
    onInverseSurface: cream,
    inversePrimary: _white,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: cream,
  );

  const roundedRectangle = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontSize: 54,
        height: .98,
        fontWeight: FontWeight.w800,
        letterSpacing: -2.2,
        color: ink,
      ),
      headlineLarge: const TextStyle(
        fontSize: 34,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
        color: ink,
      ),
      headlineMedium: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -.5,
        color: ink,
      ),
      titleLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.45, color: ink),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.4, color: _muted),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: cream,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: _white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: _outline),
      ),
    ),
    dividerTheme: const DividerThemeData(color: _outline, thickness: 1),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: _white,
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: _outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: _outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: ink, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: _white,
        disabledBackgroundColor: mint,
        disabledForegroundColor: _muted,
        shape: roundedRectangle,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: ink),
        shape: roundedRectangle,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ink),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: ink,
      foregroundColor: _white,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: _white,
      indicatorColor: mint,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: _white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: TextStyle(color: _white),
      actionTextColor: _white,
      behavior: SnackBarBehavior.floating,
      shape: roundedRectangle,
    ),
  );
}

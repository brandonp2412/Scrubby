import 'package:flutter/material.dart';

const ink = Color(0xFF17211E);
const fern = Color(0xFF174D3C);
const mint = Color(0xFFBDF5D8);
const cream = Color(0xFFF4F3EC);
const coral = Color(0xFFFF7657);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: fern,
      brightness: Brightness.light,
      primary: fern,
      secondary: coral,
      surface: cream,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: cream,
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
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: ink.withValues(alpha: .68),
      ),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .78),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: ink.withValues(alpha: .1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: ink.withValues(alpha: .1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: fern, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

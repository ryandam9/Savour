import 'package:flutter/material.dart';

abstract final class SavourColors {
  static const paper = Color(0xFFFAF6F0);
  static const cream = Color(0xFFFFFCF8);
  static const ink = Color(0xFF302720);
  static const muted = Color(0xFF897F74);
  static const terracotta = Color(0xFFCA6851);
  static const plum = Color(0xFF69474B);
  static const sand = Color(0xFFF0E7DA);
  static const line = Color(0xFFE9DFD3);
  static const paleRose = Color(0xFFF5E3DD);
}

ThemeData buildSavourTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SavourColors.terracotta,
    brightness: Brightness.light,
    surface: SavourColors.cream,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'DM Sans',
    colorScheme: scheme.copyWith(
      primary: SavourColors.terracotta,
      onPrimary: Colors.white,
      surface: SavourColors.cream,
      onSurface: SavourColors.ink,
      outline: SavourColors.line,
    ),
    scaffoldBackgroundColor: SavourColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: SavourColors.paper,
      foregroundColor: SavourColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SavourColors.cream,
      hintStyle: const TextStyle(color: SavourColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: SavourColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: SavourColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: SavourColors.terracotta, width: 1.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SavourColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerColor: SavourColors.line,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: SavourColors.terracotta,
    ),
  );
}

TextStyle editorialTitle({double size = 38, FontWeight weight = FontWeight.w500}) =>
    TextStyle(
      fontFamily: 'Cormorant Garamond',
      fontSize: size,
      fontWeight: weight,
      height: 1.05,
      letterSpacing: -0.55,
      color: SavourColors.ink,
    );

TextStyle eyebrow({double size = 10}) => const TextStyle(
  fontFamily: 'DM Sans',
  fontWeight: FontWeight.w800,
  letterSpacing: 2.1,
  color: SavourColors.terracotta,
).copyWith(fontSize: size);

// Reusable editorial font for overlays, branding and secondary serif accents.
TextStyle savourSerif({
  required double size,
  Color color = SavourColors.ink,
  FontWeight weight = FontWeight.w500,
  double? height,
}) => TextStyle(
  fontFamily: 'Cormorant Garamond',
  fontSize: size,
  fontWeight: weight,
  height: height,
  color: color,
);

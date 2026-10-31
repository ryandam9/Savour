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
  final theme = ThemeData(
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
    // The scheme's outline is the pale divider colour, which made the off
    // switch nearly invisible, so give switches explicit colours.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return SavourColors.muted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return SavourColors.terracotta;
        }
        return SavourColors.sand;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return SavourColors.muted;
      }),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: SavourColors.terracotta,
    ),
  );
  return theme.copyWith(textTheme: _liningFigures(theme.textTheme));
}

// Cormorant Garamond defaults to old-style numerals, where "1" looks like a
// capital "I". Every text style inherits lining (modern) numerals instead.
const _lining = [FontFeature.liningFigures()];

TextTheme _liningFigures(TextTheme theme) => TextTheme(
  displayLarge: theme.displayLarge?.copyWith(fontFeatures: _lining),
  displayMedium: theme.displayMedium?.copyWith(fontFeatures: _lining),
  displaySmall: theme.displaySmall?.copyWith(fontFeatures: _lining),
  headlineLarge: theme.headlineLarge?.copyWith(fontFeatures: _lining),
  headlineMedium: theme.headlineMedium?.copyWith(fontFeatures: _lining),
  headlineSmall: theme.headlineSmall?.copyWith(fontFeatures: _lining),
  titleLarge: theme.titleLarge?.copyWith(fontFeatures: _lining),
  titleMedium: theme.titleMedium?.copyWith(fontFeatures: _lining),
  titleSmall: theme.titleSmall?.copyWith(fontFeatures: _lining),
  bodyLarge: theme.bodyLarge?.copyWith(fontFeatures: _lining),
  bodyMedium: theme.bodyMedium?.copyWith(fontFeatures: _lining),
  bodySmall: theme.bodySmall?.copyWith(fontFeatures: _lining),
  labelLarge: theme.labelLarge?.copyWith(fontFeatures: _lining),
  labelMedium: theme.labelMedium?.copyWith(fontFeatures: _lining),
  labelSmall: theme.labelSmall?.copyWith(fontFeatures: _lining),
);

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

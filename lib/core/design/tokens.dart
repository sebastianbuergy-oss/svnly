import 'package:flutter/material.dart';

abstract final class SvnlyColors {
  static const background = Color(0xFF05070A);
  static const deepNavy = Color(0xFF080D16);
  static const surface = Color(0xFF111722);
  static const elevated = Color(0xFF171E2A);
  static const lime = Color(0xFFE8FF00);
  static const limePressed = Color(0xFFC4D800);
  static const text = Color(0xFFF7F8FA);
  static const secondaryText = Color(0xFFA6AFBD);
  static const mutedText = Color(0xFF6E7785);
  static const error = Color(0xFFFF5D5D);
  static const warning = Color(0xFFFFA63D);
  static const success = Color(0xFF2ED47A);
}

abstract final class SvnlySpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class SvnlyRadius {
  static const double small = 10;
  static const double medium = 18;
  static const double large = 28;
  static const double pill = 999;
}

ThemeData buildSvnlyTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SvnlyColors.lime,
    brightness: Brightness.dark,
    primary: SvnlyColors.lime,
    onPrimary: SvnlyColors.background,
    surface: SvnlyColors.surface,
    error: SvnlyColors.error,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: SvnlyColors.background,
    fontFamily: '.SF Pro Display',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: SvnlyColors.text,
        fontWeight: FontWeight.w900,
        letterSpacing: -2.5,
      ),
      headlineLarge: TextStyle(
        color: SvnlyColors.text,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineMedium: TextStyle(
        color: SvnlyColors.text,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: SvnlyColors.text,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: SvnlyColors.text, height: 1.35),
      bodyMedium: TextStyle(color: SvnlyColors.secondaryText, height: 1.4),
      labelLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .35),
    ),
    cardTheme: const CardThemeData(
      color: SvnlyColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(SvnlyRadius.medium)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: SvnlyColors.surface,
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.all(Radius.circular(SvnlyRadius.medium)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: SvnlyColors.lime, width: 2),
        borderRadius: BorderRadius.all(Radius.circular(SvnlyRadius.medium)),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: SvnlyColors.lime,
        foregroundColor: SvnlyColors.background,
        disabledBackgroundColor: SvnlyColors.mutedText,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(SvnlyRadius.medium)),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: SvnlyColors.text,
        side: const BorderSide(color: SvnlyColors.mutedText),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(SvnlyRadius.medium)),
        ),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: SvnlyColors.deepNavy,
      indicatorColor: SvnlyColors.lime,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

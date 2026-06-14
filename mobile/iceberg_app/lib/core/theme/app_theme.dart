import 'package:flutter/material.dart';
import 'ice_tokens.dart';

// ─── ICEBERG Design Tokens ──────────────────────────────────────────────────
class IceColors {
  // Primary teal scale
  static const navy = Color(0xFF06343A); // darkest teal
  static const navyMid = Color(0xFF073B42); // mid teal
  static const navyDeep = Color(0xFF0E6873); // iceberg teal
  // Accent — iceberg blue highlight (use on dark backgrounds; requires dark text)
  static const lime = Color(0xFF38BDF0);
  static const limeAlt = Color(0xFF7FE0FF);
  // Legacy alias so existing `IceColors.cyan` refs keep compiling
  static const cyan = Color(0xFF0E6873); // = navyDeep
  static const cyanGlow = Color(0x290E6873);
  static const bg = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF4FAFB);
  static const border = Color(0xFFDCEAEC);
  static const text = Color(0xFF06343A);
  static const muted = Color(0xFF6B7F83);
  static const success = Color(0xFF38A169);
  static const warning = Color(0xFFE5A936);
  static const danger = Color(0xFFE56B6F);
  static const info = Color(0xFF0284C7);

  // Dark mode overrides
  static const darkBg = Color(0xFF040F10);
  static const darkSurface = Color(0xFF071518);
  static const darkBorder = Color(0xFF0F2F33);
  static const darkText = Color(0xFFDCEAEC);
  static const darkMuted = Color(0xFF6B7F83);
}

class IceTheme {
  // Shared border-radius constants
  static const r = 24.0;
  static const rSm = 14.0;
  static const rLg = 32.0;

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: IceColors.navyDeep,
      primary: IceColors.navyDeep,
      secondary: IceColors.cyan,
      surface: IceColors.surface,
      onPrimary: Colors.white,
      onSurface: IceColors.text,
    ),
    scaffoldBackgroundColor: IceColors.bg,
    pageTransitionsTheme: icePageTransitionsTheme,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        color: IceColors.text,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: IceColors.text,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: IceColors.text,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: IceColors.text,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: IceColors.muted,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: IceColors.bg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: IceColors.text,
      ),
      iconTheme: const IconThemeData(color: IceColors.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: IceColors.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: IceColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: IceColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: IceColors.cyan, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: IceColors.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: IceColors.muted,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: IceColors.muted,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: IceColors.navyDeep,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: IceColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: IceColors.border, width: 1.5),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerColor: IceColors.border,
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: IceColors.surface,
      selectedItemColor: IceColors.navyDeep,
      unselectedItemColor: IceColors.muted,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
  );

  static ThemeData dark() => light().copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: IceColors.navyDeep,
      brightness: Brightness.dark,
      primary: IceColors.cyan,
      secondary: IceColors.navyMid,
      surface: IceColors.darkSurface,
      onSurface: IceColors.darkText,
    ),
    scaffoldBackgroundColor: IceColors.darkBg,
    cardTheme: CardThemeData(
      color: IceColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: IceColors.darkBorder, width: 1.5),
      ),
      margin: EdgeInsets.zero,
    ),
  );
}

// ─── Gradient helpers ────────────────────────────────────────────────────────
const kHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [IceColors.navy, IceColors.navyMid, IceColors.navyDeep],
  stops: [0.0, 0.52, 1.0],
);

// Lime accent gradient for highlight banners
const kLimeGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [IceColors.lime, IceColors.limeAlt],
);

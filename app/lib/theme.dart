import 'package:flutter/material.dart';

abstract class CosmicColors {
  static const background = Color(0xFF070B1E);
  static const background2 = Color(0xFF0A0E27);
  static const surface = Color(0xFF111736);
  static const surface2 = Color(0xFF1A2148);
  static const line = Color(0xFF262F60);
  static const accent = Color(0xFF6C63FF);
  static const accent2 = Color(0xFF00D4FF);
  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFFB7185);
  static const warning = Color(0xFFFBBF24);
  static const text = Color(0xFFF4F6FF);
  static const text2 = Color(0xFFC3C9EA);
  static const muted = Color(0xFF8B94BE);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: CosmicColors.accent,
    secondary: CosmicColors.accent2,
    surface: CosmicColors.surface,
    onSurface: CosmicColors.text,
    error: CosmicColors.danger,
    onPrimary: Colors.white,
    onSecondary: Color(0xFF04121F),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: CosmicColors.background,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: CosmicColors.text,
      displayColor: CosmicColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: CosmicColors.text,
    ),
    cardTheme: CardThemeData(
      color: CosmicColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: CosmicColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CosmicColors.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CosmicColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CosmicColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CosmicColors.accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: CosmicColors.muted),
      hintStyle: const TextStyle(color: CosmicColors.muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: CosmicColors.surface,
      indicatorColor: CosmicColors.accent.withValues(alpha: 0.22),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? CosmicColors.text
              : CosmicColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? CosmicColors.accent2
              : CosmicColors.muted,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: CosmicColors.surface2,
      contentTextStyle: TextStyle(color: CosmicColors.text),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: CosmicColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: CosmicColors.line),
      ),
    ),
    dividerColor: CosmicColors.line,
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: CosmicColors.surface2,
      selectedColor: CosmicColors.accent.withValues(alpha: 0.3),
      side: const BorderSide(color: CosmicColors.line),
      labelStyle: const TextStyle(color: CosmicColors.text2, fontSize: 12),
    ),
  );
}

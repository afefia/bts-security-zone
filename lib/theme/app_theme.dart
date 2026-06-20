import 'package:flutter/material.dart';

class AppTheme {
  // Palette
  static const Color navyDark = Color(0xFF0A1628);
  static const Color navyMid = Color(0xFF112240);
  static const Color steelBlue = Color(0xFF1E3A5F);
  static const Color goldAccent = Color(0xFFD4A017);
  static const Color goldLight = Color(0xFFF0C040);
  static const Color offWhite = Color(0xFFF5F6FA);
  static const Color textMuted = Color(0xFF8892A4);
  static const Color dangerRed = Color(0xFFE63946);
  static const Color successGreen = Color(0xFF2EC4B6);
  static const Color cardBg = Color(0xFF172A46);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: navyDark,
      colorScheme: const ColorScheme.dark(
        primary: goldAccent,
        secondary: steelBlue,
        surface: cardBg,
        error: dangerRed,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: offWhite,
          letterSpacing: 0.5,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: offWhite,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: offWhite,
          letterSpacing: 0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: offWhite,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          color: offWhite,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: textMuted,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: navyDark,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: navyMid,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: goldAccent),
        titleTextStyle: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: offWhite,
          letterSpacing: 0.5,
        ),
      ),

      // ── ElevatedButton — primary action, gold with navy text ──────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldAccent,
          foregroundColor: navyDark,
          disabledBackgroundColor: goldAccent.withOpacity(0.35),
          disabledForegroundColor: navyDark.withOpacity(0.5),
          elevation: 2,
          shadowColor: goldAccent.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
          iconSize: 18,
          animationDuration: Duration(milliseconds: 150),
        ).copyWith(
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 0;
            if (states.contains(WidgetState.hovered)) return 4;
            return 2;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFFB8870E); // slightly darker gold on press
            }
            if (states.contains(WidgetState.disabled)) {
              return goldAccent.withOpacity(0.35);
            }
            return goldAccent;
          }),
        ),
      ),

      // ── OutlinedButton — secondary action, gold border ────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldAccent,
          disabledForegroundColor: textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: const BorderSide(color: goldAccent, width: 1.5),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
          iconSize: 18,
        ).copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: textMuted.withOpacity(0.4), width: 1);
            }
            if (states.contains(WidgetState.pressed)) {
              return const BorderSide(color: goldLight, width: 1.5);
            }
            return const BorderSide(color: goldAccent, width: 1.5);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return textMuted;
            if (states.contains(WidgetState.pressed)) return goldLight;
            return goldAccent;
          }),
          overlayColor: WidgetStateProperty.all(goldAccent.withOpacity(0.08)),
        ),
      ),

      // ── TextButton — tertiary/inline action, understated ─────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: goldAccent,
          disabledForegroundColor: textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return textMuted;
            if (states.contains(WidgetState.pressed)) return goldLight;
            return goldAccent;
          }),
          overlayColor: WidgetStateProperty.all(goldAccent.withOpacity(0.08)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: steelBlue.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: steelBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: steelBlue.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: goldAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: dangerRed.withOpacity(0.7)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dangerRed, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
        errorStyle: const TextStyle(color: dangerRed, fontSize: 11),
        prefixIconColor: goldAccent,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: steelBlue.withOpacity(0.4)),
        ),
      ),
    );
  }
}

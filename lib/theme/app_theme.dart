import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InkFlowColors {
  static const Color primary = Color(0xFF0D0D14);
  static const Color accent = Color(0xFF8ECDC8);
  static const Color background = Color(0xFFF8F8F8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF717182);
  static const Color border = Color(0x14000000);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

class InkFlowTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: InkFlowColors.primary,
        secondary: InkFlowColors.accent,
        surface: InkFlowColors.white,
        error: InkFlowColors.error,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: InkFlowColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: InkFlowColors.primary,
        foregroundColor: InkFlowColors.white,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: InkFlowColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

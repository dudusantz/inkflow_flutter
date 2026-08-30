import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InkFlowColors {
  static const primary = Color(0xFF111116);
  static const primarySoft = Color(0xFF25252D);
  static const accent = Color(0xFF62C8C0);
  static const accentDark = Color(0xFF247C76);
  static const background = Color(0xFFF6F5F2);
  static const white = Color(0xFFFFFFFF);
  static const cardBg = Color(0xFFFFFFFF);
  static const text = Color(0xFF1B1B22);
  static const textMuted = Color(0xFF6F707C);
  static const border = Color(0xFFE7E4DF);
  static const success = Color(0xFF168A61);
  static const error = Color(0xFFD94646);
  static const warning = Color(0xFFE59A23);

  static const heroGradient = LinearGradient(
    colors: [primary, Color(0xFF282A31)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class InkFlowSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class InkFlowTheme {
  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: InkFlowColors.accent,
      primary: InkFlowColors.primary,
      surface: InkFlowColors.white,
      error: InkFlowColors.error,
    );
    final text = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: InkFlowColors.background,
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(
          color: InkFlowColors.text,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: text.titleLarge?.copyWith(
          color: InkFlowColors.text,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
        ),
        titleMedium: text.titleMedium?.copyWith(
          color: InkFlowColors.text,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: text.bodyLarge?.copyWith(
          color: InkFlowColors.text,
          height: 1.45,
        ),
        bodyMedium: text.bodyMedium?.copyWith(
          color: InkFlowColors.textMuted,
          height: 1.45,
        ),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: InkFlowColors.background,
        foregroundColor: InkFlowColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(
          color: InkFlowColors.text,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: InkFlowColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: InkFlowColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: InkFlowColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: InkFlowColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: Color(0xFF9999A3)),
        labelStyle: const TextStyle(color: InkFlowColors.textMuted),
        border: _inputBorder(InkFlowColors.border),
        enabledBorder: _inputBorder(InkFlowColors.border),
        focusedBorder: _inputBorder(InkFlowColors.accentDark, 1.6),
        errorBorder: _inputBorder(InkFlowColors.error),
        focusedErrorBorder: _inputBorder(InkFlowColors.error, 1.6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: InkFlowColors.primary,
          foregroundColor: InkFlowColors.white,
          elevation: 0,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: InkFlowColors.primary,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          side: const BorderSide(color: InkFlowColors.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: InkFlowColors.accentDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: InkFlowColors.white,
        selectedColor: InkFlowColors.accent.withValues(alpha: .18),
        side: const BorderSide(color: InkFlowColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(
          color: InkFlowColors.text,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: InkFlowColors.white,
        selectedItemColor: InkFlowColors.primary,
        unselectedItemColor: InkFlowColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: InkFlowColors.primarySoft,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: InkFlowColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: InkFlowColors.accentDark,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

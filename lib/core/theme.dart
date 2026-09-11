import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color accent50 = Color(0xFFE3F2FD);
  static const Color accent100 = Color(0xFFBBDEFB);
  static const Color accent300 = Color(0xFF90CAF9);
  static const Color accent500 = Color(0xFF2196F3);
  static const Color accent700 = Color(0xFF1976D2);
  static const Color accent900 = Color(0xFF0D47A1);

  static const Color neutral50 = Color(0xFFFFFFFF);
  static const Color neutral100 = Color(0xFFFCFCFC);
  static const Color neutral200 = Color(0xFFF2F2F2);
  static const Color neutral300 = Color(0xFFE4E4E7);
  static const Color neutral400 = Color(0xFFD4D4D8);
  static const Color neutral500 = Color(0xFFA1A1AA);
  static const Color neutral600 = Color(0xFF71717A);
  static const Color neutral700 = Color(0xFF52525B);
  static const Color neutral800 = Color(0xFF3F3F46);
  static const Color neutral900 = Color(0xFF27272A);

  static const Color successBg = Color(0xFFE8FCF4);
  static const Color successText = Color(0xFF027E74);
  static const Color errorBg = Color(0xFFFFEDF0);
  static const Color errorText = Color(0xFFE61464);
  static const Color warningBg = Color(0xFFFFF7E6);
  static const Color warningText = Color(0xFFDB6607);
  static const Color infoBg = Color(0xFFEBF3FE);
  static const Color infoText = Color(0xFF026BD8);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent500,
        primary: accent500,
        secondary: accent700,
        surface: neutral50,
        error: errorText,
      ),
      scaffoldBackgroundColor: neutral50,
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: neutral50,
        foregroundColor: neutral900,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: neutral50,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: neutral200),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neutral50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: neutral300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorText),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent700,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neutral800,
          side: const BorderSide(color: neutral300),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

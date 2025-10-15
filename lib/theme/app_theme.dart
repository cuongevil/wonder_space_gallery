import 'package:flutter/material.dart';

/// 🎨 Chủ đề pastel Wonder Space Gallery
class AppTheme {
  static const Color pink = Color(0xFFF8E8EE);
  static const Color lavender = Color(0xFFE4D4F0);
  static const Color cream = Color(0xFFFFF9F5);
  static const Color ink = Color(0xFF2E2A32);
  static const Color inkSoft = Color(0xFF6B6670);
  static const Color line = Color(0xFFE7E3EA);
  static const Color primary = Color(0xFF7C6DB0);
  static const Color primarySoft = Color(0xFFA596CC);

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      background: cream,
      surface: Colors.white,
      primary: primary,
    ),
    scaffoldBackgroundColor: cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontFamily: 'Nunito', fontSize: 15),
    ),
  );
}

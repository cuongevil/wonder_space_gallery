import 'package:flutter/material.dart';

/// 🎨 AppTheme — Hệ màu và style thống nhất cho Wonderforge ecosystem
class AppTheme {
  // 🌈 Màu chủ đạo phong cách TPBank Mobile
  static const Color primary = Color(0xFF5E2CED); // tím chính
  static const Color primarySoft = Color(
    0xFFE8DFFF,
  ); // tím nhạt pastel (nền phụ)
  static const Color secondary = Color(0xFFFF8B00); // cam sáng
  static const Color lavender = Color(0xFFA58CFF); // tím nhẹ
  static const Color ink = Color(0xFF1E1E2E); // text chính đậm
  static const Color inkSoft = Color(0xFFB5B5C3); // text phụ
  static const Color cream = Color(0xFFFDF6FF); // nền sáng mềm pastel

  // 🌸 Nền chuẩn pastel cho toàn app
  static const Color bg = Color(0xFFF9F8FF);

  // ✨ Gradient nền tím–cam pastel
  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFFF6F3FF), Color(0xFFFFF8F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // 🔹 Đường kẻ, border, divider
  static const Color line = Color(0xFFE9E5F8);

  // 🌫️ Shadow nhẹ kiểu fintech sang trọng
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.deepPurple.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  /// 🌞 Theme sáng — hiện đại, pastel mềm mại
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Poppins',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      dividerColor: line,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: bg,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }

  /// 🌙 Theme tối (dự phòng)
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: const Color(0xFF1E1E2E),
      fontFamily: 'Poppins',
      dividerColor: Colors.white12,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
      ),
    );
  }

  /// 🎨 Nút gradient tím-cam (CTA chính)
  static BoxDecoration gradientButton() {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [primary, secondary],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: primary.withOpacity(0.3),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

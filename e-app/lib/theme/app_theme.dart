import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF080808);
  static const brand = Color(0xFF1A3C6E);
  static const brandDeep = Color(0xFF102D53);
  static const interactive = Color(0xFF2B7FFF);
  static const body = Color(0xFF172B4D);
  static const bodySoft = Color(0xFF4D5F78);
  static const muted = Color(0xFF6B7A90);
  static const canvas = Color(0xFFFFFFFF);
  static const background = Color(0xFFF5F7FA);
  static const hairline = Color(0xFFE6EBF2);
  static const primarySoft = Color(0xFFEAF2FF);
  static const purple = Color(0xFF7A3DFF);
  static const orange = Color(0xFFFF6B00);
  static const green = Color(0xFF1B9A72);
  static const warningSoft = Color(0xFFFFF4E5);
  static const red = Color(0xFFEE1D36);

  static const interactiveSoft = primarySoft;
  static const textPrimary = body;
  static const textSecondary = bodySoft;
  static const textMuted = muted;
  static const success = green;
  static const warning = Color(0xFFD7811D);
  static const error = red;
  static const accentOrange = orange;
  static const accentPurple = purple;
}

abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.interactive,
      onPrimary: Colors.white,
      secondary: AppColors.purple,
      error: AppColors.red,
      surface: AppColors.canvas,
      onSurface: AppColors.ink,
      outline: AppColors.hairline,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamilyFallback: const ['Inter', 'PingFang SC', 'Microsoft YaHei'],
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.brand,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: AppColors.brand,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.brand,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: AppColors.body, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(color: AppColors.body, fontSize: 14, height: 1.5),
        bodySmall: TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          height: 1.45,
        ),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: AppColors.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.canvas,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brand,
        centerTitle: false,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 68,
        backgroundColor: AppColors.canvas,
        indicatorColor: AppColors.primarySoft,
      ),
    );
  }
}

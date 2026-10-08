import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF080808);
  static const brand = Color(0xFF1A3C6E);
  static const brandDeep = Color(0xFF102D53);
  static const primary = brand;
  static const interactive = Color(0xFF2B7FFF);
  static const body = Color(0xFF172B4D);
  static const bodySoft = Color(0xFF4D5F78);
  static const muted = Color(0xFF6B7A90);
  static const canvas = Color(0xFFFFFFFF);
  static const background = Color(0xFFF5F7FA);
  static const hairline = Color(0xFFE6EBF2);
  static const primarySoft = Color(0xFFEAF2FF);
  static const purple = Color(0xFF7A3DFF);
  static const pink = Color(0xFFED52CB);
  static const blue = Color(0xFF3B89FF);
  static const orange = Color(0xFFFF6B00);
  static const green = Color(0xFF1B9A72);
  static const warning = Color(0xFFD7811D);
  static const warningSoft = Color(0xFFFFF4E5);
  static const yellow = Color(0xFFFFAE13);
  static const red = Color(0xFFEE1D36);
}

abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.interactive,
      onPrimary: Colors.white,
      secondary: AppColors.purple,
      onSecondary: Colors.white,
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
        headlineLarge: TextStyle(
          color: AppColors.brand,
          fontSize: 30,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: AppColors.brand,
          fontSize: 24,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: AppColors.brand,
          fontSize: 20,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.brand,
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: AppColors.body, fontSize: 16, height: 1.6),
        bodyMedium: TextStyle(
          color: AppColors.body,
          fontSize: 14,
          height: 1.55,
        ),
        bodySmall: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
        color: AppColors.canvas,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.interactive,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.hairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.canvas,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: AppColors.interactive,
            width: 1.5,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.canvas,
        selectedColor: AppColors.primarySoft,
        side: const BorderSide(color: AppColors.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: const TextStyle(color: AppColors.bodySoft, fontSize: 13),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 68,
        backgroundColor: AppColors.canvas,
        indicatorColor: AppColors.primarySoft,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brand,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.brand,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.brand,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.interactive,
        dividerColor: AppColors.hairline,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: AppColors.hairline,
    );
  }
}

import 'package:flutter/material.dart';

/// Colours of a Rayalaseema home: red-oxide floors, chalk muggulu,
/// turmeric, kumkum, marigold and mango leaves.
class AppColors {
  AppColors._();

  static const redOxide = Color(0xFF8A2E1C);
  static const redOxideDark = Color(0xFF5A1A10);
  static const night = Color(0xFF2A0D08);
  static const chalk = Color(0xFFF7EEDD);
  static const turmeric = Color(0xFFF4B400);
  static const marigold = Color(0xFFF57C00);
  static const kumkum = Color(0xFFD32F2F);
  static const mangoLeaf = Color(0xFF2E7D32);
  static const leafLight = Color(0xFF66BB6A);
  static const goatCream = Color(0xFFFFF8E7);
  static const tigerOrange = Color(0xFFFF9800);
  static const tigerDeep = Color(0xFFBF5300);
  static const hint = Color(0xFF4FC3F7);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.marigold,
    brightness: Brightness.dark,
    primary: AppColors.turmeric,
    onPrimary: AppColors.night,
    secondary: AppColors.marigold,
    surface: AppColors.redOxideDark,
    onSurface: AppColors.chalk,
    error: AppColors.kumkum,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.night,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.chalk,
      elevation: 0,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.turmeric,
        foregroundColor: AppColors.night,
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.chalk,
        minimumSize: const Size(48, 52),
        side: BorderSide(color: AppColors.chalk.withValues(alpha: 0.5), width: 1.5),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.redOxideDark,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.redOxideDark),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Background used behind every screen.
const appBackground = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.redOxideDark, AppColors.night],
  ),
);

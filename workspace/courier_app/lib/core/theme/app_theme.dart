import 'package:flutter/material.dart';

/// Единая тема курьерского приложения TUR TUK.
///
/// Белый фон + бордовый акцент — стиль зафиксирован в брифе как ориентир
/// клиента ("Самокат"). Значение `#8B0000` — то же, что использует
/// клиентское приложение (`client_app/lib/core/theme/app_theme.dart`):
/// оно было выбрано первым и явно названо в задаче на клиентское приложение.
/// Настоящего брендбука пока нет (логотип лежит в `unreadable[]` брифа —
/// вложение, содержимое которого не видно), поэтому обе палитры держим
/// синхронными, а не расходящимися «примерно бордовыми».
class AppColors {
  const AppColors._();

  static const Color bordeaux = Color(0xFF8B0000);
  static const Color bordeauxDark = Color(0xFF6B0000);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F5F5);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF2E7D32);
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.bordeaux,
      brightness: Brightness.light,
      primary: AppColors.bordeaux,
      surface: AppColors.background,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bordeaux,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.bordeaux),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bordeaux, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

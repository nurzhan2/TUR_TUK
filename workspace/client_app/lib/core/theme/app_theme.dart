import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Палитра TUR TUK.
///
/// Ориентир — «Самокат»: белое полотно, один акцентный цвет и границы
/// вместо теней. Акцент означает ровно одно — «сюда нажимать»; расползётся
/// по украшениям, и витрина перестанет вести взгляд к кнопке «в корзину».
///
/// Имена [accent], [surface], [border], [textMuted] заданы контрактом
/// задачи. Прежние [bordeaux], [background], [textPrimary], [textSecondary]
/// оставлены псевдонимами: на них уже стоит экран `splash`, который пишет
/// другая сессия, и переименование сломало бы чужой файл.
class AppColors {
  const AppColors._();

  static const Color accent = Color(0xFF8B0000);
  static const Color accentDark = Color(0xFF6E0000);
  static const Color accentSoft = Color(0xFFFBEDED);
  static const Color surface = Color(0xFFF6F6F7);
  static const Color border = Color(0xFFEEEEEF);
  static const Color textMuted = Color(0xFF8A8A8E);

  static const Color background = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFE08A00);

  /// Псевдонимы прежних имён — см. пояснение у класса.
  static const Color bordeaux = accent;
  static const Color textSecondary = textMuted;
}

/// Радиусы и отступы одним местом: карточка товара, поле ввода и кнопка
/// обязаны иметь ОДИН радиус, иначе экран выглядит собранным из кусков.
class AppSizes {
  const AppSizes._();

  static const double radius = 16;
  static const double radiusSmall = 12;
  static const double gap = 12;
  static const double pagePadding = 16;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.border),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
        border: _inputBorder(BorderSide.none),
        enabledBorder: _inputBorder(BorderSide.none),
        focusedBorder:
            _inputBorder(const BorderSide(color: AppColors.accent, width: 1.5)),
        errorBorder:
            _inputBorder(const BorderSide(color: AppColors.error, width: 1.5)),
        focusedErrorBorder:
            _inputBorder(const BorderSide(color: AppColors.error, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      // Карточка БЕЗ тени, с бордером: тень на белом фоне даёт грязный серый
      // ореол, а тонкая рамка держит сетку и на светлых фото товаров.
      cardTheme: CardThemeData(
        color: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accent,
        disabledColor: AppColors.surface,
        checkmarkColor: Colors.white,
        side: BorderSide.none,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: StadiumBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.accent),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textMuted,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        subtitleTextStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(BorderSide side) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        borderSide: side,
      );

  /// Крупные жирные заголовки — главный приём «Самоката»: название и цена
  /// читаются с расстояния вытянутой руки, а подписи уходят в серый.
  static const TextTheme _textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
      letterSpacing: -0.5,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary),
    bodyMedium:
        TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
    bodySmall: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.35),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 11, color: AppColors.textMuted),
  );
}

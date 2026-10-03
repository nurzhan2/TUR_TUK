import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/content/app_content.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_image.dart';

/// Экран загрузки.
///
/// Уводит в каталог ВСЕГДА, даже когда профиль не восстановился. Упереться
/// в форму входа посреди показа заказчице — худший исход демонстрации, а
/// вход никуда не девается: он живёт отдельным экраном и открывается из
/// профиля.
///
/// Логотип клиента на момент сборки прочитать не удалось (вложение попало
/// в `brief.unreadable[]`), поэтому здесь текстовый знак в фирменных
/// цветах. Придёт файл — `_Logo` меняется на `Image.asset` без переделки
/// экрана.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Профиль подтягиваем молча и не ждём: если хранилище тормозит,
      // заставка не должна из-за этого висеть.
      unawaited(context.read<AuthController>().load());
    });
    _redirectTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) context.go(AppRoutes.catalog);
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
          child: const _Logo(),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    // Логотип, название и подзаголовок — из настроек админки. Нет логотипа —
    // фирменный знак из букв названия на фирменном цвете.
    final brand = AppContent.instance.brand;
    final accent = brand.accentColor ?? AppColors.accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: brand.hasLogo ? Colors.transparent : accent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: brand.hasLogo
              ? AppImage(
                  brand.logoFile,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _Monogram(text: brand.monogram, color: accent),
                )
              : _Monogram(text: brand.monogram, color: accent),
        ),
        const SizedBox(height: 20),
        Text(
          brand.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: accent,
            letterSpacing: 1.5,
          ),
        ),
        if (brand.tagline.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            brand.tagline,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

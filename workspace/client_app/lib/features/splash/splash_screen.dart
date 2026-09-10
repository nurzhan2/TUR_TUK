import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: const Text(
            'TT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'TUR TUK',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Доставка в отели Кемера',
          style: TextStyle(fontSize: 15, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

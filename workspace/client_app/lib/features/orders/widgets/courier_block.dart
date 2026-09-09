import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// Аватар курьера: первая буква имени на мягком бордовом фоне.
///
/// Фотографий курьеров в демо-данных нет, а серый силуэт из иконки делает
/// живого человека «неизвестным пользователем» — буква читается как
/// настоящий аватар и не требует ассета.
class CourierAvatar extends StatelessWidget {
  const CourierAvatar({required this.name, this.size = 48, super.key});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.accentSoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

/// Круглая кнопка действия рядом с курьером (чат, звонок).
class CourierActionButton extends StatelessWidget {
  const CourierActionButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, size: 20, color: AppColors.accent),
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// Пара кнопок «чат» и «звонок» — одинаковая в карточке заказа и на
/// трекинге, поэтому собрана здесь, а не продублирована в двух экранах.
class CourierActions extends StatelessWidget {
  const CourierActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CourierActionButton(
          icon: Icons.chat_bubble_outline,
          onPressed: () => context.push(AppRoutes.chat),
        ),
        const SizedBox(width: 8),
        CourierActionButton(
          icon: Icons.call_outlined,
          onPressed: () => showCourierCallStub(context),
        ),
      ],
    );
  }
}

/// Звонок в демо только показывается: телефонии за приложением нет, а
/// кнопка, которая молча ничего не делает, читается как сломанная.
void showCourierCallStub(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      // TODO l10n: строки нет в общем файле, новые ключи заводить нельзя
      const SnackBar(content: Text('Звонок курьеру')),
    );
}

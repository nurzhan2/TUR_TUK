import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/order.dart';
import 'package:client_app/core/widgets/app_image.dart';

/// Стопка миниатюр позиций заказа — внахлёст, как аватары участников.
///
/// Показывает не больше четырёх фото: пятая миниатюра уже не читается, а
/// счётчик «+N» на её месте отвечает на единственный вопрос, который к
/// стопке возникает, — «сколько там всего».
class OrderThumbs extends StatelessWidget {
  const OrderThumbs({required this.items, super.key});

  final List<OrderItem> items;

  static const double _size = 40;
  static const double _overlap = 12;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final shown = items.take(4).toList();
    final rest = items.length - shown.length;
    final circles = shown.length + (rest > 0 ? 1 : 0);
    final step = _size - _overlap;

    return SizedBox(
      height: _size,
      width: _size + step * (circles - 1),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: step * i,
              child: _Circle(
                child: AppImage(
                  shown[i].imageAsset,
                  width: _size,
                  height: _size,
                  fit: BoxFit.cover,
                  // Пустой `imageAsset` приходит из боевого API (там путь
                  // может не прийти вовсе) — стопка не должна из-за этого
                  // ронять весь список заказов.
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: AppColors.surface),
                ),
              ),
            ),
          if (rest > 0)
            Positioned(
              left: step * shown.length,
              child: _Circle(
                child: Container(
                  width: _size,
                  height: _size,
                  alignment: Alignment.center,
                  color: AppColors.surface,
                  child: Text(
                    '+$rest',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: OrderThumbs._size,
      height: OrderThumbs._size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Белая обводка отделяет соседние миниатюры друг от друга: без неё
        // тёмные фото сливаются в одно пятно.
        border: Border.all(color: AppColors.background, width: 2),
        color: AppColors.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

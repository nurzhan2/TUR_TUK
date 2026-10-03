import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../models/product.dart';
import 'cart_action_button.dart';
import 'package:client_app/core/widgets/app_image.dart';

/// Карточка товара витрины — в стиле Wildberries: квадратное фото во всю
/// ширину, крупная цена, название в две строки и кнопка снизу.
///
/// Один и тот же виджет работает в сетке каталога и в узкой ленте «похожих
/// товаров» ([compact]): второй вариант отличается только кеглями и
/// высотой кнопки, а не вёрсткой — расходящиеся карточки на двух экранах
/// сразу читаются как две разные витрины.
class ProductCard extends StatelessWidget {
  const ProductCard({required this.product, this.compact = false, super.key});

  final Product product;
  final bool compact;

  double get _priceSize => compact ? 15 : 17;

  double get _nameSize => compact ? 12 : 13;

  double get _buttonHeight => compact ? 30 : 34;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      // opaque, а не обычный тап: промежутки между текстом и краем карточки
      // тоже должны открывать товар — попасть пальцем ровно в название
      // на маленьком экране почти невозможно.
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(AppRoutes.productPath(product.id)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProductPhoto(product: product, radius: AppSizes.radius),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Фото квадратное, значит под текст остаётся
                  // `высота карточки − ширина`. При `childAspectRatio: 0.58`
                  // на узком экране (320 px) этого не хватает на всё, и
                  // единица измерения уходит первой: «шт» — наименее
                  // важная строка карточки.
                  final showUnit = constraints.maxHeight >= 108;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(10, 6, 10, compact ? 8 : 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PriceRow(product: product, size: _priceSize),
                        const SizedBox(height: 2),
                        // Flexible + ClipRect — вторая страховка: если
                        // места не хватило даже без «шт», вторая строка
                        // названия обрежется, а не расцветёт полосатым
                        // overflow посреди витрины.
                        Flexible(
                          child: ClipRect(
                            child: Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: _nameSize,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        if (showUnit)
                          Text(
                            product.unit,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.2,
                              color: AppColors.textMuted,
                            ),
                          ),
                        const SizedBox(height: 3),
                        CartActionButton(
                          product: product,
                          height: _buttonHeight,
                          fontSize: compact ? 12 : 13,
                          label: l10n.addToCart,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Фото товара с бейджем скидки и плашкой «нет в наличии».
///
/// Публичный виджет: тем же фото открывается карточка товара, и второй
/// `errorBuilder` в другом файле означал бы, что однажды один из них
/// забудут — а демо на показе не должно падать из-за картинки.
class ProductPhoto extends StatelessWidget {
  const ProductPhoto({
    required this.product,
    this.radius = AppSizes.radius,
    this.showBadges = true,
    super.key,
  });

  final Product product;
  final double radius;
  final bool showBadges;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Opacity(
              // Недоступный товар видно, но он явно «выключен»: убрать его
              // из выдачи нельзя — заказчица спросит, где он.
              opacity: product.isAvailable ? 1 : 0.4,
              child: AppImage(
                product.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const _PhotoStub(),
              ),
            ),
          ),
        ),
        if (showBadges && product.hasDiscount)
          Positioned(
            left: 8,
            top: 8,
            child: _DiscountBadge(percent: product.discountPercent),
          ),
        if (showBadges && !product.isAvailable)
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                ),
                child: Text(
                  l10n.outOfStock,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Заглушка вместо не загрузившегося фото: серый прямоугольник с иконкой.
class _PhotoStub extends StatelessWidget {
  const _PhotoStub();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.image_outlined, size: 32, color: AppColors.textMuted),
      ),
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.percent, this.fontSize = 12});

  final int percent;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        // U+2212, а не дефис: настоящий минус той же ширины, что цифры,
        // и бейдж не выглядит как перенос слова.
        '−$percent%',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Бейдж скидки для карточки товара — тот же вид, что в сетке.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({required this.percent, this.fontSize = 13, super.key});

  final int percent;
  final double fontSize;

  @override
  Widget build(BuildContext context) =>
      _DiscountBadge(percent: percent, fontSize: fontSize);
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product, required this.size});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    // scaleDown, а не ellipsis: обрезанная цена («12 90…») — это ошибка на
    // витрине, а не мелкая неопрятность. На обычном телефоне пара
    // «цена + старая цена» помещается и не масштабируется вовсе; сжимается
    // только на узких экранах и только на четырёхзначных ценниках.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Flexible на обоих ценниках: FittedBox сжимает строку целиком, но
          // сначала Row обязан уложиться в отведённую ширину. Без этого пара
          // «четырёхзначная цена + зачёркнутая старая» вылезает за карточку
          // на узком экране.
          Flexible(
            child: Text(
              money(product.price),
              maxLines: 1,
              style: TextStyle(
                fontSize: size,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (product.hasDiscount) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                money(product.oldPrice!),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.1,
                  color: AppColors.textMuted,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/cart_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../models/cart.dart';
import '../../../models/product.dart';

/// Кнопка «в корзину», превращающаяся в степпер «− N +».
///
/// Вынесена из карточки отдельным виджетом, потому что подписка на корзину
/// должна начинаться ровно здесь. `context.watch<CartController>()` внутри
/// карточки перерисовал бы все тридцать карточек сетки на каждое нажатие
/// «+»: сетка мигает, фотографии передекодируются, демо выглядит тормозящим.
/// [Selector] пересобирает только эту кнопку и только когда количество
/// ИМЕННО ЭТОГО товара изменилось.
class CartActionButton extends StatelessWidget {
  const CartActionButton({
    required this.product,
    this.height = 34,
    this.fontSize = 13,
    this.label,
    this.onAdded,
    super.key,
  });

  final Product product;
  final double height;
  final double fontSize;

  /// Надпись на кнопке добавления. По умолчанию — короткое «В корзину»
  /// (`addToCart`), на карточке товара место позволяет длинное
  /// «Добавить в корзину».
  final String? label;

  /// Дёргается после добавления первой штуки — карточка товара показывает
  /// на этом SnackBar. В сетке каталога колбэка нет: тридцать всплывающих
  /// плашек подряд перекрыли бы саму витрину.
  final VoidCallback? onAdded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!product.isAvailable) {
      return _Pill(
        height: height,
        color: AppColors.surface,
        child: Text(
          l10n.outOfStock,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return Selector<CartController, int>(
      selector: (_, cart) => cart.quantityOf(product.id),
      builder: (context, quantity, _) {
        if (quantity == 0) {
          return _Pill(
            height: height,
            color: AppColors.accentSoft,
            onTap: () {
              context.read<CartController>().add(product.id);
              onAdded?.call();
            },
            child: Text(
              label ?? l10n.addToCart,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          );
        }
        return _Stepper(
          product: product,
          quantity: quantity,
          height: height,
          fontSize: fontSize,
        );
      },
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.product,
    required this.quantity,
    required this.height,
    required this.fontSize,
  });

  final Product product;
  final int quantity;
  final double height;
  final double fontSize;

  /// Позиция корзины ищется по товару в момент нажатия, а не запоминается:
  /// `setQuantity` и `remove` работают с `item.id`, и он меняется, когда
  /// позицию удалили и добавили заново.
  CartItem? _itemOf(CartController cart) {
    for (final item in cart.cart.items) {
      if (item.product.id == product.id) return item;
    }
    return null;
  }

  void _decrement(BuildContext context) {
    final cart = context.read<CartController>();
    final item = _itemOf(cart);
    if (item == null) return;
    // Единица — это «убрать из корзины», а не «ноль штук»: позиции с нулём
    // в корзине не бывает, и бэкенд на такой `setQuantity` ответит ошибкой.
    if (item.quantity <= 1) {
      cart.remove(item.id);
    } else {
      cart.setQuantity(item.id, item.quantity - 1);
    }
  }

  void _increment(BuildContext context) {
    final cart = context.read<CartController>();
    final item = _itemOf(cart);
    if (item == null) {
      cart.add(product.id);
      return;
    }
    cart.setQuantity(item.id, item.quantity + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentSoft,
      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            _StepperButton(
              icon: quantity <= 1 ? Icons.delete_outline : Icons.remove,
              size: height,
              onTap: () => _decrement(context),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$quantity',
                  style: TextStyle(
                    fontSize: fontSize + 1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
            _StepperButton(
              icon: Icons.add,
              size: height,
              onTap: () => _increment(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      child: SizedBox(
        width: size + 6,
        height: size,
        child: Center(
          child: Icon(icon, size: size * 0.5, color: AppColors.accent),
        ),
      ),
    );
  }
}

/// Общая «таблетка» кнопки: одинаковая высота и радиус у активного,
/// неактивного и добавляющего состояния — иначе кнопка прыгает по высоте
/// в момент нажатия и утаскивает за собой всю карточку.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.height,
    required this.color,
    required this.child,
    this.onTap,
  });

  final double height;
  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        child: SizedBox(
          height: height,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

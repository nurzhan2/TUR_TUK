import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/cart_controller.dart';
import '../../controllers/controller_state.dart';
import '../../core/format.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/cart.dart';
import 'cart_totals.dart';
import 'package:client_app/core/widgets/app_image.dart';

/// Корзина: позиции со степпером и свайпом, блок «Итого», плашка
/// минимальной суммы и закреплённая внизу кнопка оформления.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Загрузка после первого кадра: до вставки виджета в дерево
    // `context.read` провайдер ещё не найдёт.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CartController>().load();
    });
  }

  Future<void> _confirmClear(AppLocalizations l10n) async {
    final controller = context.read<CartController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.cartClear),
        // Отдельного ключа под вопрос в общем файле локализации нет.
        content: const Text('Все товары будут удалены из корзины.'), // TODO l10n
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.cartClear,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.clear();
  }

  /// Удаление с возможностью отмены. Количество и товар запоминаем ДО
  /// удаления: после него позиции в корзине уже нет, и вернуть её будет
  /// нечем.
  void _removeWithUndo(CartItem item) {
    final controller = context.read<CartController>();
    final messenger = ScaffoldMessenger.of(context);
    final productId = item.product.id;
    final quantity = item.quantity;
    controller.remove(item.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // Flutter 3.32+: SnackBar с action по умолчанию не скрывается сам
          // и висел над экраном до следующего уведомления.
          persist: false,
          content: const Text('Товар удалён'), // TODO l10n
          action: SnackBarAction(
            label: 'Отменить', // TODO l10n
            textColor: Colors.white,
            onPressed: () => controller.add(productId, qty: quantity),
          ),
        ),
      );
  }

  void _changeQuantity(CartItem item, int quantity) {
    final controller = context.read<CartController>();
    if (quantity <= 0) {
      _removeWithUndo(item);
      return;
    }
    controller.setQuantity(item.id, quantity);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = context.watch<CartController>();
    final cart = controller.cart;
    final totals = CartTotals(subtotal: cart.total);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cartTitle),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              tooltip: l10n.cartClear,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmClear(l10n),
            ),
        ],
      ),
      body: switch (cart.isEmpty) {
        // Спиннер только на первой загрузке: перерасчёт количества не
        // должен выбивать список из-под пальца.
        true when controller.state.isLoading =>
          const Center(child: CircularProgressIndicator()),
        true => const _EmptyCart(),
        false => _CartList(
            cart: cart,
            totals: totals,
            onQuantityChanged: _changeQuantity,
            onDismissed: _removeWithUndo,
          ),
      },
      bottomNavigationBar:
          cart.isEmpty ? null : _CheckoutBar(totals: totals, l10n: l10n),
    );
  }
}

class _CartList extends StatelessWidget {
  const _CartList({
    required this.cart,
    required this.totals,
    required this.onQuantityChanged,
    required this.onDismissed,
  });

  final Cart cart;
  final CartTotals totals;
  final void Function(CartItem item, int quantity) onQuantityChanged;
  final void Function(CartItem item) onDismissed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.gap,
        AppSizes.pagePadding,
        AppSizes.pagePadding,
      ),
      children: [
        Text(
          l10n.cartItems(cart.count),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSizes.gap),
        for (final item in cart.items)
          _CartRow(
            item: item,
            onQuantityChanged: (quantity) => onQuantityChanged(item, quantity),
            onDismissed: () => onDismissed(item),
          ),
        const SizedBox(height: AppSizes.gap),
        _TotalsCard(totals: totals),
        if (totals.belowMinOrder) ...[
          const SizedBox(height: AppSizes.gap),
          _MinOrderNotice(totals: totals),
        ],
      ],
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.item,
    required this.onQuantityChanged,
    required this.onDismissed,
  });

  final CartItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey<int>(item.id),
      // Только влево: жест «вправо» на вложенном в оболочку экране
      // конфликтует с системным «назад» на iOS.
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSizes.gap),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSizes.radius),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.gap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductThumb(asset: item.product.imageAsset),
            const SizedBox(width: AppSizes.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(item.product.unit, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Flexible на обеих цифрах: на узком экране пара
                      // «цена за штуку + сумма по строке» с четырёхзначными
                      // ценниками не влезает в колонку рядом со степпером.
                      Flexible(
                        child: Text(
                          money(item.product.price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      // Сумма по строке нужна, только когда она отличается
                      // от цены за штуку.
                      if (item.quantity > 1) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            money(item.lineTotal),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.gap),
            _QuantityStepper(
              quantity: item.quantity,
              onChanged: onQuantityChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.asset});

  final String asset;

  static const double _size = 76;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      child: SizedBox(
        width: _size,
        height: _size,
        child: asset.isEmpty
            ? const _ThumbPlaceholder()
            : AppImage(
                asset,
                fit: BoxFit.cover,
                // Битый путь к фото не должен выбрасывать красный экран
                // посреди показа — вместо него серая заглушка.
                errorBuilder: (_, _, _) => const _ThumbPlaceholder(),
              ),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surface,
      child: Icon(Icons.image_outlined, color: AppColors.textMuted),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: () => onChanged(quantity - 1),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 18, color: AppColors.accent),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});

  final CartTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _SummaryRow(
            label: l10n.checkoutSubtotal,
            value: money(totals.subtotal),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: l10n.checkoutDelivery,
            value: totals.isDeliveryFree
                ? 'Бесплатно' // TODO l10n
                : money(totals.delivery),
            valueColor: totals.isDeliveryFree ? AppColors.success : null,
          ),
          // Подсказка как в Самокате: сколько добрать до бесплатной
          // доставки. Порог задаётся в админке; 0 — подсказки нет.
          if (totals.missingToFreeDelivery > 0) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'До бесплатной доставки — ещё ${money(totals.missingToFreeDelivery)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.gap),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.cartTotal, style: theme.textTheme.titleMedium),
              Text(money(totals.total), style: theme.textTheme.headlineSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: AppSizes.gap),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _MinOrderNotice extends StatelessWidget {
  const _MinOrderNotice({required this.totals});

  final CartTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shopping_basket_outlined,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // В ключ подставляется САМ порог, а не недостача:
                    // «Минимальная сумма заказа — 1 200 ₽» при пороге
                    // 3000 ₽ читалась бы как другая минималка. Сколько
                    // добрать — отдельной строкой ниже.
                    Text(
                      l10n.cartMinOrder(money(CartTotals.minOrder)),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Добавьте товаров ещё на ${money(totals.missingToMinOrder)}', // TODO l10n
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.gap),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totals.minOrderProgress,
              minHeight: 6,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.totals, required this.l10n});

  final CartTotals totals;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: ElevatedButton(
            // `null` вместо флага: кнопка при недоборе минималки обязана
            // выглядеть выключенной, а не молча ничего не делать.
            onPressed: totals.belowMinOrder
                ? null
                : () => context.push(AppRoutes.checkout),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.cartCheckout),
                Text(money(totals.total)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 72,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 20),
            Text(
              l10n.cartEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              child: ElevatedButton(
                onPressed: () => context.go(AppRoutes.catalog),
                child: const Text('Перейти в каталог'), // TODO l10n
              ),
            ),
          ],
        ),
      ),
    );
  }
}

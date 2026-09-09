import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/order.dart';
import '../cart/cart_totals.dart';

/// «Заказ оформлен» — финал воронки покупки.
///
/// Своего маршрута у экрана нет намеренно: он открывается замещением
/// чекаута на корневом навигаторе, иначе «назад» вернуло бы на форму
/// оплаты с уже очищенной корзиной.
class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({required this.order, super.key});

  final Order order;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Уход с экрана успеха.
  ///
  /// Сначала снимаем сам экран с навигатора, и только потом зовём
  /// `go`: экран лежит поверх стека маршрутов императивно, и без `pop`
  /// он остался бы висеть над новым маршрутом.
  void _leaveTo(String location) {
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) navigator.pop();
    router.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final order = widget.order;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.checkoutSuccess,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.orderNumber(order.id),
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: AppColors.accent),
              ),
              const SizedBox(height: AppSizes.gap),
              Text(
                l10n.checkoutSuccessSub,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              Text(
                // Отель, комната и срок — то, что человек проверяет глазами
                // сразу после оплаты.
                '${order.hotelName}, № ${order.roomNumber} · 40–60 минут', // TODO l10n
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _TotalCard(order: order),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _leaveTo(AppRoutes.trackingPath(order.id)),
                child: Text(l10n.orderTrack),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _leaveTo(AppRoutes.catalog),
                child: const Text('В каталог'), // TODO l10n
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.checkoutTotal,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
          // Итог пересчитываем тем же [CartTotals], что и чекаут, а не
          // берём `order.total`: демо-заказ всегда прибавляет доставку
          // 300 ₽, не зная про её бесплатность от 5000 ₽, и на корзине
          // от 5000 ₽ сумма на этом экране разошлась бы с той, которую
          // человек только что видел на кнопке «Оплатить».
          Text(
            money(CartTotals(
              subtotal: order.subtotal,
              discount: order.discount,
            ).total),
            style: theme.textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

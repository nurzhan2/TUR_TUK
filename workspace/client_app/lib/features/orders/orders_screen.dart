import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/cart_controller.dart';
import '../../controllers/controller_state.dart';
import '../../controllers/orders_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'widgets/order_card.dart';

/// История заказов: статус, состав, повтор доставленного.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    // Загрузка после первого кадра: `load()` синхронно зовёт
    // `notifyListeners`, а из `initState` это прилетело бы в дерево,
    // которое ещё строится.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final orders = context.read<OrdersController>();
      // Только если данных ещё нет: возврат с карточки заказа не должен
      // заново дёргать список и терять позицию прокрутки.
      if (orders.state == ControllerState.initial) orders.load();
    });
  }

  Future<void> _repeat(int id) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final orders = context.read<OrdersController>();
    final cart = context.read<CartController>();

    try {
      await orders.repeat(id);
      // Повтор кладёт позиции в корзину мимо `CartController`, поэтому
      // корзину перечитываем сами — иначе бейдж в нижней навигации
      // останется со старым числом, и повтор будет выглядеть впустую.
      await cart.load();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            // Flutter 3.32+: SnackBar с action по умолчанию не скрывается сам
            // и висел над экраном до следующего уведомления.
            persist: false,
            // TODO l10n: строк нет в общем файле, новые ключи заводить нельзя
            content: const Text('Товары добавлены в корзину'),
            action: SnackBarAction(
              label: 'В корзину',
              textColor: Colors.white,
              onPressed: () => router.go(AppRoutes.cart),
            ),
          ),
        );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.loadingError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = context.watch<OrdersController>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ordersTitle)),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () => context.read<OrdersController>().load(),
          child: _body(controller, l10n),
        ),
      ),
    );
  }

  Widget _body(OrdersController controller, AppLocalizations l10n) {
    // Пока список пуст, состояние решает всё; когда заказы уже показаны,
    // перезагрузка не должна подменять их спиннером — это «моргание»
    // на каждом pull-to-refresh.
    if (controller.orders.isEmpty) {
      if (controller.state.isLoading || controller.state == ControllerState.initial) {
        return const _OrdersSkeleton();
      }
      if (controller.state.isError) {
        return _Message(
          icon: Icons.cloud_off_outlined,
          text: l10n.loadingError,
          actionLabel: l10n.retry,
          onAction: () => context.read<OrdersController>().load(),
        );
      }
      return _Message(
        icon: Icons.receipt_long_outlined,
        text: l10n.ordersEmpty,
        actionLabel: l10n.catalogTitle,
        onAction: () => context.go(AppRoutes.catalog),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: controller.orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSizes.gap),
      itemBuilder: (context, index) {
        final order = controller.orders[index];
        return OrderCard(
          order: order,
          onTap: () => context.push(AppRoutes.orderPath(order.id)),
          onTrack: () => context.push(AppRoutes.trackingPath(order.id)),
          onRepeat: () => _repeat(order.id),
        );
      },
    );
  }
}

/// Пустой экран и ошибка — одна и та же вёрстка: иконка, строка, кнопка.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    // Прокручиваемый, чтобы pull-to-refresh работал и на пустом списке.
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Icon(icon, size: 56, color: AppColors.textMuted),
        const SizedBox(height: AppSizes.gap),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 220,
            child: ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ),
        ),
      ],
    );
  }
}

/// Три карточки-заглушки с пульсацией вместо спиннера: экран сразу
/// показывает будущую форму списка, и загрузка не читается как пустота.
class _OrdersSkeleton extends StatefulWidget {
  const _OrdersSkeleton();

  @override
  State<_OrdersSkeleton> createState() => _OrdersSkeletonState();
}

class _OrdersSkeletonState extends State<_OrdersSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: AppSizes.gap),
      itemBuilder: (context, index) => AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Opacity(
          opacity: 0.45 + 0.35 * _pulse.value,
          child: child,
        ),
        child: const _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _bar(width: 120, height: 18),
              const Spacer(),
              _bar(width: 76, height: 22, radius: 999),
            ],
          ),
          const SizedBox(height: AppSizes.gap),
          _bar(width: 180, height: 12),
          const SizedBox(height: 8),
          _bar(width: 220, height: 12),
          const SizedBox(height: AppSizes.gap),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _bar(width: 40, height: 40, radius: 999),
                ),
              const Spacer(),
              _bar(width: 80, height: 18),
            ],
          ),
          const SizedBox(height: AppSizes.gap),
          _bar(width: double.infinity, height: 44, radius: AppSizes.radius),
        ],
      ),
    );
  }

  Widget _bar({required double width, required double height, double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

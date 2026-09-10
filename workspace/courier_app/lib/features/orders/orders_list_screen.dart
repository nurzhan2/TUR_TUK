import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'order_model.dart';
import 'order_status_view.dart';
import 'orders_controller.dart';

/// Главный экран курьера: смена, разложенная на три секции.
///
/// Секции, а не один плоский список: у курьера три разных вопроса к экрану —
/// «что можно взять», «что я должен довезти», «что уже закрыто», — и в общем
/// списке первый теряется среди третьего.
class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OrdersController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final orders = context.watch<OrdersController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ordersTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logoutButton,
            onPressed: () => context.read<AuthController>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: orders.load,
        child: _body(context, l10n, orders),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    OrdersController controller,
  ) {
    switch (controller.state) {
      case OrdersLoadState.initial:
      case OrdersLoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case OrdersLoadState.error:
        return _ErrorView(
          message: controller.errorMessage == 'network_error'
              ? l10n.ordersLoadError
              : controller.errorMessage ?? l10n.ordersLoadError,
          onRetry: controller.load,
          retryLabel: l10n.ordersRetryButton,
        );
      case OrdersLoadState.loaded:
        if (controller.orders.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 140),
              Center(
                child: Text(
                  l10n.ordersEmpty,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _Section(
              title: l10n.sectionNew,
              orders: controller.newOrders,
              emptyLabel: l10n.sectionEmpty,
            ),
            _Section(
              title: l10n.sectionInProgress,
              orders: controller.inProgressOrders,
              emptyLabel: l10n.sectionEmpty,
            ),
            _Section(
              title: l10n.sectionDone,
              orders: controller.completedOrders,
              emptyLabel: l10n.sectionEmpty,
            ),
          ],
        );
    }
  }
}

/// Секция с заголовком и счётчиком.
///
/// Пустая секция НЕ прячется: исчезнувший заголовок «Новые» неотличим от
/// «раздел не загрузился», а курьеру важно видеть именно то, что новых
/// заказов сейчас нет.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.orders,
    required this.emptyLabel,
  });

  final String title;
  final List<Order> orders;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            24,
            AppSizes.pagePadding,
            12,
          ),
          child: Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 8),
              Text(
                '${orders.length}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (orders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.pagePadding,
            ),
            child: Text(
              emptyLabel,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          )
        else
          for (final order in orders)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                0,
                AppSizes.pagePadding,
                AppSizes.gap,
              ),
              child: OrderCard(order: order),
            ),
      ],
    );
  }
}

/// Карточка заказа в списке. Отвечает на четыре вопроса курьера сразу:
/// куда везти, сколько там позиций, на какую сумму и когда оформлен.
class OrderCard extends StatelessWidget {
  const OrderCard({required this.order, super.key});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: () => context.go(AppRoutes.orderPath(order.id)),
      borderRadius: BorderRadius.circular(AppSizes.radius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.orderNumber(order.id),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusPill(status: order.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.hotel_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.orderAddress(order.hotelName, order.roomNumber),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  money(order.total),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.orderItemsCount(order.itemsCount),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Text(
                  timeOfDay(order.createdAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final Future<void> Function() onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    );
  }
}

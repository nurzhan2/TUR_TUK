import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'order_model.dart';
import 'orders_controller.dart';

/// Главный экран курьерского приложения — список новых заказов.
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
      context.read<OrdersController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ordersController = context.watch<OrdersController>();

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
        onRefresh: ordersController.load,
        child: _buildBody(context, l10n, ordersController),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n, OrdersController controller) {
    switch (controller.state) {
      case OrdersLoadState.initial:
      case OrdersLoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case OrdersLoadState.error:
        return _ErrorView(
          message: controller.errorMessage == 'network_error'
              ? l10n.ordersLoadError
              : controller.errorMessage!,
          onRetry: controller.load,
          l10n: l10n,
        );
      case OrdersLoadState.loaded:
        if (controller.orders.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 120),
              Center(
                child: Text(l10n.ordersEmpty, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _OrderCard(order: controller.orders[index], l10n: l10n),
        );
    }
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.l10n});

  final Order order;
  final AppLocalizations l10n;

  String _statusLabel() {
    switch (order.status) {
      case OrderStatus.created:
        return l10n.orderStatusCreated;
      case OrderStatus.accepted:
        return l10n.orderStatusAccepted;
      case OrderStatus.assembling:
        return l10n.orderStatusAssembling;
      case OrderStatus.delivering:
        return l10n.orderStatusDelivering;
      case OrderStatus.delivered:
        return l10n.orderStatusDelivered;
      case OrderStatus.cancelled:
        return l10n.orderStatusCancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.orderNumber(order.id), style: Theme.of(context).textTheme.titleMedium),
                _StatusPill(label: _statusLabel()),
              ],
            ),
            const SizedBox(height: 8),
            Text('${order.hotelName}, №${order.roomNumber}'),
            const SizedBox(height: 4),
            Text('${order.total.toStringAsFixed(2)} ₽'),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bordeaux.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.bordeaux, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry, required this.l10n});

  final String message;
  final Future<void> Function() onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.error_outline, size: 48, color: AppColors.error),
        const SizedBox(height: 12),
        Center(child: Text(message, textAlign: TextAlign.center)),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: onRetry,
            child: Text(l10n.ordersRetryButton),
          ),
        ),
      ],
    );
  }
}

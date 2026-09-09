import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/controller_state.dart';
import '../../controllers/orders_controller.dart';
import '../../core/format.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/order.dart';
import 'widgets/courier_block.dart';
import 'widgets/order_format.dart';
import 'widgets/order_timeline.dart';
import 'widgets/status_pill.dart';

/// Карточка заказа: таймлайн стадий, курьер, состав, итог и фото доставки.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    // На карточку заказа можно прийти по прямой ссылке (`/orders/1042`),
    // минуя список — тогда заказов в контроллере ещё нет. Грузим ОДИН раз:
    // если заказа нет и после загрузки, повтор ничего не изменит, только
    // зациклит экран.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final orders = context.read<OrdersController>();
      if (orders.byId(widget.orderId) == null &&
          orders.state == ControllerState.initial) {
        orders.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = context.watch<OrdersController>();
    final order = controller.byId(widget.orderId);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderNumber(widget.orderId))),
      body: order == null
          ? _placeholder(controller, l10n)
          : _content(order, l10n),
      bottomNavigationBar: order == null || order.status.isFinal
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(AppSizes.pagePadding),
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.trackingPath(order.id)),
                child: Text(l10n.orderTrack),
              ),
            ),
    );
  }

  Widget _placeholder(OrdersController controller, AppLocalizations l10n) {
    if (controller.state.isLoading || controller.state == ControllerState.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: AppSizes.gap),
            Text(
              // TODO l10n: строки нет в общем файле, новые ключи заводить нельзя
              'Заказ не найден',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(Order order, AppLocalizations l10n) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        Row(
          children: [
            StatusPill(status: order.status),
            const SizedBox(width: AppSizes.gap),
            Expanded(
              child: Text(
                orderDateTime(order.createdAt),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (order.status == OrderStatus.cancelled)
          _CancelledBanner(label: l10n.orderStatusCancelled)
        else
          _Section(child: OrderTimeline(order: order)),
        if (order.courierName != null) ...[
          const SizedBox(height: AppSizes.gap),
          _CourierCard(name: order.courierName!, caption: l10n.orderCourier),
        ],
        const SizedBox(height: AppSizes.gap),
        _AddressCard(order: order, title: l10n.orderDeliveryTo),
        const SizedBox(height: 20),
        Text(l10n.orderItems, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSizes.gap),
        _Section(
          child: Column(
            children: [
              for (var i = 0; i < order.items.length; i++) ...[
                if (i > 0) const Divider(height: 24),
                _OrderLine(item: order.items[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.gap),
        _Totals(order: order, l10n: l10n),
        if (order.deliveryPhotoAsset != null) ...[
          const SizedBox(height: 24),
          Text(l10n.orderDeliveryPhoto, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSizes.gap),
          _DeliveryPhoto(asset: order.deliveryPhotoAsset!),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Секция карточки: белый блок с рамкой, без тени — как остальной интерфейс.
class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, color: AppColors.error),
          const SizedBox(width: AppSizes.gap),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierCard extends StatelessWidget {
  const _CourierCard({required this.name, required this.caption});

  final String name;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Section(
      child: Row(
        children: [
          CourierAvatar(name: name),
          const SizedBox(width: AppSizes.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleMedium),
                Text(caption, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const CourierActions(),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.order, required this.title});

  final Order order;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Section(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_outlined,
                color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: AppSizes.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  '${order.hotelName}, №${order.roomNumber}',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderLine extends StatelessWidget {
  const _OrderLine({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          child: Image.asset(
            item.imageAsset,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 44,
              height: 44,
              color: AppColors.surface,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                '${item.quantity} × ${money(item.price)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.gap),
        Text(
          money(item.lineTotal),
          style: theme.textTheme.titleSmall,
        ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.order, required this.l10n});

  final Order order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Section(
      child: Column(
        children: [
          _row(theme, l10n.checkoutSubtotal, money(order.subtotal)),
          if (order.discount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l10n.checkoutDiscount, style: theme.textTheme.bodyMedium),
                if (order.promoCode != null) ...[
                  const SizedBox(width: 6),
                  Text(order.promoCode!, style: theme.textTheme.labelSmall),
                ],
                const Spacer(),
                Text(
                  '−${money(order.discount)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          _row(theme, l10n.checkoutDelivery, money(order.deliveryFee)),
          const Divider(height: 24),
          Row(
            children: [
              Text(l10n.checkoutTotal, style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                money(order.total),
                style: theme.textTheme.displaySmall?.copyWith(fontSize: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Row(
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

/// Фото коробки у рецепции — самое убедительное доказательство доставки,
/// поэтому во всю ширину, а не миниатюрой в углу.
class _DeliveryPhoto extends StatelessWidget {
  const _DeliveryPhoto({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                color: AppColors.surface,
                child: Icon(Icons.image_not_supported_outlined,
                    color: AppColors.textMuted),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          // TODO l10n: строки нет в общем файле, новые ключи заводить нельзя
          'Коробка передана на рецепцию',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

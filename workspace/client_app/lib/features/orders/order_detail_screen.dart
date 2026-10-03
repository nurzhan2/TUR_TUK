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
import 'package:client_app/core/widgets/app_image.dart';

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
        if (order.status == OrderStatus.delivered) ...[
          const SizedBox(height: 24),
          _RateCard(order: order),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Оценка доставки — один раз, после доставки. Звёзды крупные, отзыв
/// необязателен: чем меньше трения, тем больше оценок у владелицы.
class _RateCard extends StatefulWidget {
  const _RateCard({required this.order});

  final Order order;

  @override
  State<_RateCard> createState() => _RateCardState();
}

class _RateCardState extends State<_RateCard> {
  int _stars = 0;
  bool _sending = false;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await context.read<OrdersController>().rate(
            widget.order.id,
            _stars,
            comment: _comment.text,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить оценку — попробуйте ещё раз')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rated = widget.order.rating;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        child: rated != null
            ? Row(
                children: [
                  const Text('Ваша оценка', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  for (var i = 1; i <= 5; i++)
                    Icon(i <= rated ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFE0A100)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Как прошла доставка?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          iconSize: 36,
                          onPressed: _sending ? null : () => setState(() => _stars = i),
                          icon: AnimatedScale(
                            scale: i <= _stars ? 1.15 : 1,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: const Color(0xFFE0A100),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_stars > 0) ...[
                    TextField(
                      controller: _comment,
                      maxLines: 2,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: 'Комментарий (необязательно)',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: const StadiumBorder(),
                          minimumSize: const Size.fromHeight(46),
                        ),
                        onPressed: _sending ? null : _send,
                        child: Text(_sending ? 'Отправляем…' : 'Отправить оценку'),
                      ),
                    ),
                  ],
                ],
              ),
      ),
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
          child: AppImage(
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
            child: AppImage(
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

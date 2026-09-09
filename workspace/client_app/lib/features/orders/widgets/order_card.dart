import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../models/order.dart';
import 'order_format.dart';
import 'order_thumbs.dart';
import 'status_pill.dart';

/// Карточка заказа в списке.
///
/// Действия приходят колбэками, а не вызываются здесь: повтор заказа
/// трогает корзину и показывает `SnackBar`, и держать это в виджете-строке
/// значит протащить в него половину экрана.
class OrderCard extends StatelessWidget {
  const OrderCard({
    required this.order,
    required this.onTap,
    required this.onTrack,
    required this.onRepeat,
    super.key,
  });

  final Order order;
  final VoidCallback onTap;
  final VoidCallback onTrack;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppSizes.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: Container(
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
                  Expanded(
                    child: Text(
                      l10n.orderNumber(order.id),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: AppSizes.gap),
                  StatusPill(status: order.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(orderDateTime(order.createdAt), style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSizes.gap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${l10n.orderDeliveryTo} ${order.hotelName}, №${order.roomNumber}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.gap),
              Row(
                children: [
                  OrderThumbs(items: order.items),
                  const Spacer(),
                  Text(
                    money(order.total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              ..._actions(l10n),
            ],
          ),
        ),
      ),
    );
  }

  /// У отменённого заказа кнопки нет вовсе: отслеживать нечего, а
  /// «повторить» на отмене предлагает повторить неудачу.
  List<Widget> _actions(AppLocalizations l10n) {
    if (!order.status.isFinal) {
      return [
        const SizedBox(height: AppSizes.gap),
        ElevatedButton(
          onPressed: onTrack,
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          child: Text(l10n.orderTrack),
        ),
      ];
    }
    if (order.status == OrderStatus.delivered) {
      return [
        const SizedBox(height: AppSizes.gap),
        OutlinedButton(
          onPressed: onRepeat,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          child: Text(l10n.orderRepeat),
        ),
      ];
    }
    return const [];
  }
}

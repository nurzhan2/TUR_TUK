import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../models/order.dart';

/// Цвет стадии заказа.
///
/// Синий «принят» задан литералом, а не взят из [AppColors]: синего в
/// палитре нет вовсе, а без него «принят» и «собираем» слились бы в один
/// тёплый цвет — и шкала статусов перестала бы читаться с одного взгляда,
/// ради чего пилюля и заводилась.
Color orderStatusColor(OrderStatus status) => switch (status) {
      OrderStatus.created => AppColors.textMuted,
      OrderStatus.accepted => const Color(0xFF2F6FED),
      OrderStatus.assembling => AppColors.warning,
      OrderStatus.delivering => AppColors.accent,
      OrderStatus.delivered => AppColors.success,
      OrderStatus.cancelled => AppColors.error,
    };

/// Подпись стадии. Отдельной функцией, а не полем модели: `OrderStatus`
/// живёт в слое данных и о языке интерфейса знать не должен.
String orderStatusLabel(AppLocalizations l10n, OrderStatus status) =>
    switch (status) {
      OrderStatus.created => l10n.orderStatusCreated,
      OrderStatus.accepted => l10n.orderStatusAccepted,
      OrderStatus.assembling => l10n.orderStatusAssembling,
      OrderStatus.delivering => l10n.orderStatusDelivering,
      OrderStatus.delivered => l10n.orderStatusDelivered,
      OrderStatus.cancelled => l10n.orderStatusCancelled,
    };

/// Пилюля статуса: один и тот же виджет в списке заказов, в карточке и на
/// трекинге. Три копии одной раскраски однажды разошлись бы — и «в пути»
/// на карте оказался бы другого цвета, чем «в пути» в списке.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = orderStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        orderStatusLabel(l10n, status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

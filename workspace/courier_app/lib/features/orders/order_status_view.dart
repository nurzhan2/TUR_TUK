import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'order_model.dart';

/// Как статус выглядит и называется. Одно место на всё приложение: список и
/// карточка заказа показывают одну и ту же пилюлю, и разъехавшиеся подписи
/// («в пути» в списке, «доставляется» в карточке) читаются как два разных
/// состояния одного заказа.
String statusLabel(AppLocalizations l10n, OrderStatus status) =>
    switch (status) {
      OrderStatus.created => l10n.orderStatusCreated,
      OrderStatus.accepted => l10n.orderStatusAccepted,
      OrderStatus.assembling => l10n.orderStatusAssembling,
      OrderStatus.delivering => l10n.orderStatusDelivering,
      OrderStatus.delivered => l10n.orderStatusDelivered,
      OrderStatus.cancelled => l10n.orderStatusCancelled,
    };

/// Цвет статуса. Бордовый акцент здесь НЕ используется: он означает «сюда
/// нажимать», и пилюля в нём тянула бы взгляд на себя вместо кнопки. Работа
/// идёт — оранжевый, закрыто — зелёный, отменено — красный, новое — серое.
Color statusColor(OrderStatus status) => switch (status) {
  OrderStatus.created => AppColors.textMuted,
  OrderStatus.accepted => AppColors.warning,
  OrderStatus.assembling => AppColors.warning,
  OrderStatus.delivering => AppColors.warning,
  OrderStatus.delivered => AppColors.success,
  OrderStatus.cancelled => AppColors.error,
};

class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        // Подложка того же цвета с малой прозрачностью, а не белый фон
        // с рамкой: пилюль на экране до пяти, и пять рамок дают рябь.
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel(AppLocalizations.of(context)!, status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

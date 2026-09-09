import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../models/order.dart';
import 'order_format.dart';

/// Вертикальный таймлайн заказа: пять шагов от «создан» до «доставлен».
///
/// Главный элемент карточки заказа — по нему клиент за секунду понимает,
/// где его коробка. Отменённый заказ сюда не попадает: у него `step == -1`,
/// и шкала прогресса для него бессмысленна (см. `OrderDetailScreen`).
class OrderTimeline extends StatefulWidget {
  const OrderTimeline({required this.order, super.key});

  final Order order;

  @override
  State<OrderTimeline> createState() => _OrderTimelineState();
}

class _OrderTimelineState extends State<OrderTimeline>
    with SingleTickerProviderStateMixin {
  /// Ореол текущего шага: полторы секунды на вдох-выдох. Быстрее — экран
  /// начинает мигать и тянуть внимание на себя, медленнее — пульс не
  /// читается как «прямо сейчас происходит».
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  /// Высота шага: круг 24 плюс отрезок линии до следующего.
  static const double _stepHeight = 56;
  static const double _dot = 24;

  /// Модель не хранит время каждой стадии — на бэкенде его тоже нет, есть
  /// только `created_at`. Показываем правдоподобную шкалу от момента
  /// оформления: без времени пройденные шаги выглядят как выключенные
  /// галочки, а не как история заказа.
  static const List<Duration> _offsets = [
    Duration.zero,
    Duration(minutes: 3),
    Duration(minutes: 9),
    Duration(minutes: 18),
    Duration(minutes: 35),
  ];

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = widget.order.status.step;
    final labels = [
      l10n.orderStatusCreated,
      l10n.orderStatusAccepted,
      l10n.orderStatusAssembling,
      l10n.orderStatusDelivering,
      l10n.orderStatusDelivered,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var step = 0; step < labels.length; step++)
          _step(step: step, current: current, label: labels[step], last: step == labels.length - 1),
      ],
    );
  }

  Widget _step({
    required int step,
    required int current,
    required String label,
    required bool last,
  }) {
    final passed = step < current;
    final isCurrent = step == current;
    final theme = Theme.of(context);
    final time = passed || isCurrent
        ? orderTime(widget.order.createdAt.add(_offsets[step]))
        : null;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _dot,
          child: Column(
            children: [
              _circle(passed: passed, isCurrent: isCurrent),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    // Линия «пройдена» вместе с шагом, из которого выходит:
                    // так бордовая нить видно докуда доехал заказ.
                    color: passed ? AppColors.accent : AppColors.border,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.gap),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 15,
                    color: passed || isCurrent
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                if (time != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(time, style: theme.textTheme.labelSmall),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    return last ? row : SizedBox(height: _stepHeight, child: row);
  }

  Widget _circle({required bool passed, required bool isCurrent}) {
    if (passed) {
      return Container(
        width: _dot,
        height: _dot,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 15, color: Colors.white),
      );
    }

    if (!isCurrent) {
      return Container(
        width: _dot,
        height: _dot,
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 2),
        ),
      );
    }

    return SizedBox(
      width: _dot,
      height: _dot,
      // Ореол шире самого круга и вылезает за пределы колонки — обрезать
      // его нельзя, иначе пульс превратится в мигающий квадрат.
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              return Container(
                width: _dot + 16 * _pulse.value,
                height: _dot + 16 * _pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent
                      .withValues(alpha: 0.22 * (1 - _pulse.value)),
                ),
              );
            },
          ),
          Container(
            width: _dot,
            height: _dot,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: SizedBox(
                width: 8,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

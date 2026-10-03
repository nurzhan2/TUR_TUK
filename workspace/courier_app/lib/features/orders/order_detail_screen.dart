import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/location/location_tracker.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'order_model.dart';
import 'order_status_view.dart';
import 'orders_controller.dart';

/// Карточка заказа: что везти, кому и что делать дальше.
///
/// Кнопка следующего шага здесь ОДНА. Показать курьеру все стадии сразу
/// («собрать», «выехать», «доставить») значит дать нажать «доставлен» из
/// машины по дороге на склад — и потерять единственный признак, по которому
/// диспетчер видит, где заказ на самом деле.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = context.watch<OrdersController>();
    final order = controller.byId(orderId);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.orderNotFound)),
      );
    }

    final busy = controller.busy.contains(order.id);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderNumber(order.id))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          0,
          AppSizes.pagePadding,
          24,
        ),
        children: [
          if (order.status == OrderStatus.delivering &&
              controller.trackingProblem != null) ...[
            _TrackingProblemBanner(
              problem: controller.trackingProblem!,
              onRetry: () => controller.retryTracking(order.id),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              StatusPill(status: order.status),
              const Spacer(),
              Text(
                l10n.orderCreatedAt(timeOfDay(order.createdAt)),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ItemsCard(order: order),
          const SizedBox(height: 12),
          _GuestNotes(order: order),
          const SizedBox(height: AppSizes.gap),
          _ClientCard(order: order),
          const SizedBox(height: AppSizes.gap),
          if (order.deliveryPhotoAsset != null) ...[
            _DeliveryPhotoCard(asset: order.deliveryPhotoAsset!),
            const SizedBox(height: AppSizes.gap),
          ],
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.routePath(order.id)),
            icon: const Icon(Icons.map_outlined, size: 20),
            label: Text(l10n.actionRoute),
          ),
          const SizedBox(height: 20),
          _Actions(order: order, busy: busy),
          if (controller.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              controller.errorMessage == 'network_error'
                  ? l10n.ordersLoadError
                  : controller.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _Card(
      title: l10n.orderItemsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (order.items.isEmpty)
            // Боевой `GET /orders` состав не отдаёт — говорим об этом прямо,
            // а не рисуем пустой список, который читается как «заказ пуст».
            Text(
              l10n.orderItemsUnavailable,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            )
          else
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Количество слева и жирным: курьер сверяет им коробку,
                    // и это первое, что он ищет глазами.
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${item.quantity}×',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      money(item.lineTotal),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.orderTotal,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              Text(
                money(order.total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _Card(
      title: l10n.orderClientTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (order.clientName.isNotEmpty)
            Text(
              order.clientName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          if (order.clientPhone.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.clientPhone,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                // Звонок — единственное действие, которое курьеру нужно
                // из карточки прямо сейчас: гостья не открыла дверь, и он
                // звонит, не переписывая номер в набиратель.
                TextButton.icon(
                  onPressed: () => _call(context, order.clientPhone),
                  icon: const Icon(Icons.call, size: 18),
                  label: Text(l10n.orderCall),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _Field(label: l10n.orderHotel, value: order.hotelName),
          const SizedBox(height: 10),
          _Field(label: l10n.orderRoom, value: order.roomNumber),
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    // Пробелы и дефисы из показанного номера в `tel:` не годятся — набиратель
    // получает голые цифры и ведущий плюс.
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$digits');
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context)!.routeLaunchFailed;
    if (!await launchUrl(uri)) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}

class _DeliveryPhotoCard extends StatelessWidget {
  const _DeliveryPhotoCard({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _Card(
      title: l10n.deliveryPhotoTitle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.asset(asset, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

/// Кнопки шага. Для нового заказа их две — решение принять или отклонить,
/// и они равноправны; для принятого одна — следующая стадия.
class _Actions extends StatelessWidget {
  const _Actions({required this.order, required this.busy});

  final Order order;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = context.read<OrdersController>();

    if (order.isNew) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: busy ? null : () => controller.accept(order.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: busy ? const _Spinner() : Text(l10n.actionAccept),
          ),
          const SizedBox(height: AppSizes.gap),
          OutlinedButton(
            onPressed: busy ? null : () => _confirmReject(context, controller),
            child: Text(l10n.actionReject),
          ),
        ],
      );
    }

    final next = order.status.next;
    if (next == null) return const SizedBox.shrink();

    return ElevatedButton(
      onPressed: busy
          ? null
          : () {
              // «Доставлен» через отдельный экран: без снимка коробки этот
              // переход подтверждать нечем, а закрыть заказ одним нажатием
              // из машины — ровно то, от чего снимок и защищает.
              if (next == OrderStatus.delivered) {
                context.go(AppRoutes.deliveryPath(order.id));
                return;
              }
              controller.advance(order.id);
            },
      child: busy ? const _Spinner() : Text(_label(l10n, next)),
    );
  }

  static String _label(AppLocalizations l10n, OrderStatus next) =>
      switch (next) {
        OrderStatus.assembling => l10n.actionStartAssembly,
        OrderStatus.delivering => l10n.actionDepart,
        OrderStatus.delivered => l10n.actionDelivered,
        _ => l10n.actionAccept,
      };

  Future<void> _confirmReject(
    BuildContext context,
    OrdersController controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.rejectConfirmTitle),
        content: Text(l10n.rejectConfirmText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionReject),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.reject(order.id);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}


/// Трекинг не запустился — курьер должен это видеть: иначе клиент смотрит
/// на пустую карту, а курьер уверен, что его ведут.
class _TrackingProblemBanner extends StatelessWidget {
  const _TrackingProblemBanner({required this.problem, required this.onRetry});

  final TrackingProblem problem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (text, action) = switch (problem) {
      TrackingProblem.serviceDisabled =>
        ('Геолокация выключена — клиент не видит вас на карте.', 'Включить'),
      TrackingProblem.permissionDenied =>
        ('Нет доступа к геолокации — клиент не видит вас на карте.', 'Разрешить'),
      TrackingProblem.permissionForever =>
        ('Доступ к геолокации запрещён в настройках телефона.', 'Настройки'),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_outlined, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
          TextButton(
            onPressed: () async {
              if (problem == TrackingProblem.serviceDisabled) {
                await Geolocator.openLocationSettings();
              } else if (problem == TrackingProblem.permissionForever) {
                await Geolocator.openAppSettings();
              }
              onRetry();
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }
}


/// Пожелания гостя: что делать, если товара нет, и комментарий к заказу.
/// Стоит сразу под составом — сборщик видит это ДО того, как начнёт сборку.
class _GuestNotes extends StatelessWidget {
  const _GuestNotes({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final comment = order.comment;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, size: 20, color: AppColors.textMuted),
              const SizedBox(width: 8),
              const Text('Если товара нет: ', style: TextStyle(color: AppColors.textMuted)),
              Expanded(
                child: Text(order.ifMissingLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(child: Text(comment, style: const TextStyle(fontSize: 15))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

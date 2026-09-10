import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/demo/demo_data.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'orders_controller.dart';

/// Подтверждение доставки снимком коробки.
///
/// Отдельный экран, а не диалог: это единственное необратимое действие
/// курьера, и оно требует снимка. Диалог с двумя кнопками закрывался бы
/// случайным тапом, а заказ считался бы доставленным.
///
/// Камеры в демо нет — по нажатию подставляется заранее подготовленный
/// ассет, тот же, что клиентское приложение показывает в карточке
/// доставленного заказа. Работа с настоящей камерой (`image_picker` плюс
/// multipart-загрузка в `POST /orders/{id}/delivery-photo`) — отдельная
/// задача; здесь важно, что порядок действий уже правильный: сначала
/// снимок, потом подтверждение.
class DeliveryConfirmScreen extends StatefulWidget {
  const DeliveryConfirmScreen({required this.orderId, super.key});

  final int orderId;

  @override
  State<DeliveryConfirmScreen> createState() => _DeliveryConfirmScreenState();
}

class _DeliveryConfirmScreenState extends State<DeliveryConfirmScreen> {
  String? _photo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = context.watch<OrdersController>();
    final order = controller.byId(widget.orderId);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.orderNotFound)),
      );
    }

    final busy = controller.busy.contains(order.id);
    final photo = _photo;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deliveryTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          0,
          AppSizes.pagePadding,
          24,
        ),
        children: [
          Text(
            l10n.orderNumber(order.id),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.orderAddress(order.hotelName, order.roomNumber),
            style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: photo == null
                ? _PhotoPlaceholder(hint: l10n.deliveryHint)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radius),
                    child: Image.asset(photo, fit: BoxFit.cover),
                  ),
          ),
          const SizedBox(height: 20),
          if (photo == null)
            ElevatedButton.icon(
              onPressed: () => setState(() => _photo = DemoData.boxPhoto),
              icon: const Icon(Icons.photo_camera_outlined, size: 20),
              label: Text(l10n.deliveryTakePhoto),
            )
          else ...[
            ElevatedButton(
              onPressed: busy ? null : () => _confirm(order.id, photo),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.deliveryConfirm),
            ),
            const SizedBox(height: AppSizes.gap),
            OutlinedButton(
              onPressed: busy ? null : () => setState(() => _photo = null),
              child: Text(l10n.deliveryRetakePhoto),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirm(int id, String photo) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final ok = await context.read<OrdersController>().confirmDelivery(
      id,
      photoAsset: photo,
    );
    if (!mounted) return;
    if (!ok) return;

    messenger.showSnackBar(SnackBar(content: Text(l10n.deliveryDone)));
    // Возвращаемся в карточку заказа, а не в список: курьер видит, что
    // статус сменился и снимок на месте, — то есть что действие сработало.
    router.go(AppRoutes.orderPath(id));
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.photo_camera_outlined,
            size: 44,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

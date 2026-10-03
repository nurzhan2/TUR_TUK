import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/demo/demo_data.dart';
import '../../core/demo/demo_mode.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'orders_controller.dart';
import 'orders_repository.dart';

/// Подтверждение доставки снимком коробки.
///
/// Отдельный экран, а не диалог: это единственное необратимое действие
/// курьера, и оно требует снимка. Диалог с двумя кнопками закрывался бы
/// случайным тапом, а заказ считался бы доставленным.
///
/// Боевой режим: камера телефона (`image_picker`), снимок ужимается до
/// 1600 px и уходит в `POST /orders/{id}/delivery-photo` ДО смены статуса.
/// Демо: подставляется заранее подготовленный ассет — показ без камеры.
class DeliveryConfirmScreen extends StatefulWidget {
  const DeliveryConfirmScreen({required this.orderId, super.key});

  final int orderId;

  @override
  State<DeliveryConfirmScreen> createState() => _DeliveryConfirmScreenState();
}

class _DeliveryConfirmScreenState extends State<DeliveryConfirmScreen> {
  DeliveryPhoto? _photo;
  bool _picking = false;

  Future<void> _takePhoto() async {
    if (kDemoMode) {
      setState(() => _photo = const DeliveryPhoto.asset(DemoData.boxPhoto));
      return;
    }
    setState(() => _picking = true);
    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (shot == null || !mounted) return;
      final bytes = await shot.readAsBytes();
      final mime = shot.mimeType ??
          (shot.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
      setState(() => _photo = DeliveryPhoto.bytes(bytes, filename: shot.name, mimeType: mime));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Камера недоступна. Разрешите доступ к камере в настройках телефона.'),
      ));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

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
                    child: _PhotoPreview(photo: photo),
                  ),
          ),
          const SizedBox(height: 20),
          if (controller.errorMessage != null && photo != null) ...[
            Text(
              controller.errorMessage == 'network_error'
                  ? 'Нет связи — снимок не отправлен. Попробуйте ещё раз.'
                  : controller.errorMessage!,
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 12),
          ],
          if (photo == null)
            ElevatedButton.icon(
              onPressed: _picking ? null : _takePhoto,
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

  Future<void> _confirm(int id, DeliveryPhoto photo) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final ok = await context.read<OrdersController>().confirmDelivery(id, photo: photo);
    if (!mounted) return;
    if (!ok) return;

    messenger.showSnackBar(SnackBar(content: Text(l10n.deliveryDone)));
    // Возвращаемся в карточку заказа, а не в список: курьер видит, что
    // статус сменился и снимок на месте, — то есть что действие сработало.
    router.go(AppRoutes.orderPath(id));
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photo});

  final DeliveryPhoto photo;

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = photo.bytes;
    if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
    return Image.asset(photo.asset ?? '', fit: BoxFit.cover);
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

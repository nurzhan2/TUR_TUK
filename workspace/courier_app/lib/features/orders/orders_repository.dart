import 'dart:typed_data';

import '../../core/demo/demo_mode.dart';
import '../../core/demo/demo_state.dart';
import '../../core/network/api_client.dart';
import 'order_model.dart';

/// Снимок коробки у двери/на рецепции. В демо — путь к ассету, в бою —
/// байты JPEG с камеры (уже ужатые `image_picker` до ~1600 px).
class DeliveryPhoto {
  const DeliveryPhoto.asset(String this.asset)
      : bytes = null,
        filename = 'box.jpg',
        mimeType = 'image/jpeg';

  const DeliveryPhoto.bytes(
    Uint8List this.bytes, {
    this.filename = 'box.jpg',
    this.mimeType = 'image/jpeg',
  }) : asset = null;

  final String? asset;
  final Uint8List? bytes;
  final String filename;
  final String mimeType;
}

/// Заказы курьера. Реализаций две — демо и боевая, выбор стоит в [Di].
///
/// Каждое действие возвращает ОБНОВЛЁННЫЙ заказ, а не `void`: экран деталей
/// показывает статус, и без возврата ему пришлось бы перезапрашивать весь
/// список после каждой кнопки — то есть мигать содержимым на каждый шаг.
abstract class OrdersRepository {
  Future<List<Order>> fetchOrders();

  Future<Order> accept(int id);

  Future<Order> reject(int id);

  /// Следующая стадия рабочего процесса: сборка -> выехал -> доставлен.
  Future<Order> advance(int id);

  Future<Order> confirmDelivery(int id, {required DeliveryPhoto photo});
}

class DemoOrdersRepository implements OrdersRepository {
  const DemoOrdersRepository();

  @override
  Future<List<Order>> fetchOrders() async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.orders;
  }

  @override
  Future<Order> accept(int id) async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.accept(id);
  }

  @override
  Future<Order> reject(int id) async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.reject(id);
  }

  @override
  Future<Order> advance(int id) async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.advance(id);
  }

  @override
  Future<Order> confirmDelivery(int id, {required DeliveryPhoto photo}) async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.confirmDelivery(id, photoAsset: photo.asset ?? '');
  }
}

/// Боевые заказы.
///
/// `GET /orders` бэкенд уже фильтрует по `courier_id == текущий пользователь`
/// для роли `courier` (см. `backend/app/api/orders.py`), так что параметров
/// не нужно. Все переходы идут одним `PATCH /orders/{id}/status`: назначение
/// курьера на свободный заказ бэкенд делает сам при принятии, отдельного
/// «взять заказ» там нет.
class ApiOrdersRepository implements OrdersRepository {
  ApiOrdersRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<Order>> fetchOrders() async {
    final json = await _apiClient.get('/orders') as List<dynamic>;
    return json
        .map((item) => Order.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Order> accept(int id) => _setStatus(id, OrderStatus.accepted);

  @override
  Future<Order> reject(int id) => _setStatus(id, OrderStatus.cancelled);

  @override
  Future<Order> advance(int id) async {
    // Куда двигаться, знает не клиент, а текущий статус заказа на сервере:
    // локальный список мог устареть, а бэкенд отклоняет недопустимые
    // переходы (`_ALLOWED_TRANSITIONS`) — то есть угадывание тут стоило бы
    // 422 вместо шага вперёд.
    final current = await _apiClient.get('/orders/$id') as Map<String, dynamic>;
    final next = Order.fromJson(current).status.next;
    if (next == null) return Order.fromJson(current);
    return _setStatus(id, next);
  }

  /// Сначала снимок, потом статус: если фото не загрузилось (нет сети в
  /// подвале отеля), заказ НЕ становится доставленным — курьер повторит.
  @override
  Future<Order> confirmDelivery(int id, {required DeliveryPhoto photo}) async {
    final bytes = photo.bytes;
    if (bytes == null) {
      throw ApiException(422, 'нужен снимок коробки с камеры');
    }
    await _apiClient.upload(
      '/orders/$id/delivery-photo',
      field: 'file',
      bytes: bytes,
      filename: photo.filename,
      contentType: photo.mimeType,
    );
    return _setStatus(id, OrderStatus.delivered);
  }

  Future<Order> _setStatus(int id, OrderStatus status) async {
    final json = await _apiClient.patch(
      '/orders/$id/status',
      body: {'status': status.name},
    ) as Map<String, dynamic>;
    return Order.fromJson(json);
  }
}

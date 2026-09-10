import '../../core/demo/demo_mode.dart';
import '../../core/demo/demo_state.dart';
import '../../core/network/api_client.dart';
import 'order_model.dart';

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

  Future<Order> confirmDelivery(int id, {required String photoAsset});
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
  Future<Order> confirmDelivery(int id, {required String photoAsset}) async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.confirmDelivery(id, photoAsset: photoAsset);
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

  /// ИЗВЕСТНЫЙ ПРОБЕЛ: снимок коробки здесь НЕ отправляется.
  ///
  /// Эндпоинт для него есть (`POST /orders/{id}/delivery-photo`), но он
  /// принимает multipart, а [ApiClient] умеет только JSON; и главное —
  /// снимать нечем: работы с камерой в приложении пока нет вовсе, а в демо
  /// показывается заранее подготовленный ассет. Статус при этом переводится
  /// честно, так что боевой сценарий курьера доходит до «доставлен» — без
  /// фотографии. Подставлять сюда демо-ассет было бы хуже: заказ выглядел
  /// бы подтверждённым снимком, которого никто не делал.
  @override
  Future<Order> confirmDelivery(int id, {required String photoAsset}) =>
      _setStatus(id, OrderStatus.delivered);

  Future<Order> _setStatus(int id, OrderStatus status) async {
    final json = await _apiClient.patch(
      '/orders/$id/status',
      body: {'status': status.name},
    ) as Map<String, dynamic>;
    return Order.fromJson(json);
  }
}

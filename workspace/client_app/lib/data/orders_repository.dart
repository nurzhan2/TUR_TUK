import 'dart:async';

import '../core/demo/demo_data.dart';
import '../core/demo/demo_state.dart';
import '../core/network/api_client.dart';
import '../models/order.dart';
import 'catalog_repository.dart' show kDemoLatency;

abstract class OrdersRepository {
  Future<List<Order>> list();

  Future<Order> byId(int id);

  Future<Order> create({
    required String hotelName,
    required String roomNumber,
    String? promoCode,
    String? comment,
  });

  Future<Order> repeat(int id);

  /// Живой поток состояния заказа. В демо тикает раз в 4 секунды: двигает
  /// курьера и переключает статус.
  Stream<Order> track(int id);
}

class DemoOrdersRepository implements OrdersRepository {
  const DemoOrdersRepository();

  /// Шаг демо-трекинга. Четыре секунды — компромисс показа: за минуту
  /// разговора заказ успевает проехать весь путь и доставиться, а движение
  /// на карте при этом видно глазом, а не «дёргается» каждую секунду.
  static const Duration tickInterval = Duration(seconds: 4);

  @override
  Future<List<Order>> list() async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.orders;
  }

  @override
  Future<Order> byId(int id) async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.orderById(id);
  }

  @override
  Future<Order> create({
    required String hotelName,
    required String roomNumber,
    String? promoCode,
    String? comment,
  }) async {
    await Future<void>.delayed(kDemoLatency);
    final state = DemoState.instance;
    // Скидку считаем ЗДЕСЬ, по тому же промокоду и той же корзине: заказ
    // с итогом, не сходящимся с чекаутом, — первое, что заметит заказчица.
    var discount = 0.0;
    if (promoCode != null && promoCode.trim().isNotEmpty) {
      final code = promoCode.trim().toUpperCase();
      for (final promo in DemoData.promos()) {
        if (promo.code == code && !promo.expired) {
          discount = promo.discountFor(state.cart.total);
          break;
        }
      }
    }
    return state.createOrder(
      hotelName: hotelName,
      roomNumber: roomNumber,
      promoCode: promoCode,
      discount: discount,
    );
  }

  @override
  Future<Order> repeat(int id) async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.repeatOrder(id);
  }

  @override
  Stream<Order> track(int id) async* {
    // Первое значение — СРАЗУ, не через четыре секунды: экран трекинга,
    // который четыре секунды показывает пустоту, выглядит сломанным.
    yield DemoState.instance.orderById(id);
    while (true) {
      await Future<void>.delayed(tickInterval);
      final next = DemoState.instance.advanceTracking(id);
      if (next == null) return;
      yield next;
      if (next.status.isFinal) return;
    }
  }
}

/// Боевые заказы: `backend/app/api/orders.py`.
///
/// `track()` здесь — ОПРОС раз в 10 секунд, а не WebSocket: отдельного
/// сокета под статус заказа на бэкенде нет (сокет там только у чата,
/// см. `app/routers/chat.py`), а выдумывать несуществующий эндпоинт хуже,
/// чем честно спрашивать `GET /orders/{id}`.
class ApiOrdersRepository implements OrdersRepository {
  ApiOrdersRepository(this._api);

  final ApiClient _api;

  static const Duration pollInterval = Duration(seconds: 10);

  @override
  Future<List<Order>> list() async {
    // `/orders/history` вместо `/orders`: позиции и дата нужны и списку,
    // и карточке, а `OrderOut` их не отдаёт.
    final body = await _api.get('/orders/history') as List;
    return [
      for (final item in body) Order.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<Order> byId(int id) async {
    final body = await _api.get('/orders/$id') as Map<String, dynamic>;
    return Order.fromJson(body);
  }

  @override
  Future<Order> create({
    required String hotelName,
    required String roomNumber,
    String? promoCode,
    String? comment,
  }) async {
    // Позиции бэкенд берёт НЕ из корзины, а из тела запроса
    // (`OrderCreate.items`), поэтому корзина читается перед оформлением.
    final cart = await _api.get('/cart') as Map<String, dynamic>;
    final items = [
      for (final item in (cart['items'] as List))
        {
          'product_id': (item as Map<String, dynamic>)['product']['id'],
          'quantity': item['quantity'],
        },
    ];
    final body = await _api.post('/orders', body: {
      'hotel_name': hotelName,
      'room_number': roomNumber,
      'items': items,
      if (promoCode != null && promoCode.trim().isNotEmpty)
        'promo_code': promoCode.trim(),
    }) as Map<String, dynamic>;
    return Order.fromJson(body);
  }

  @override
  Future<Order> repeat(int id) async {
    final body = await _api.post('/orders/$id/repeat') as Map<String, dynamic>;
    // `RepeatOrderOut` — это обёртка: сам заказ лежит в поле `order`,
    // рядом с ним `skipped_items` и `warning` про недоступные товары.
    return Order.fromJson(body['order'] as Map<String, dynamic>);
  }

  @override
  Stream<Order> track(int id) async* {
    while (true) {
      final order = await byId(id);
      yield order;
      if (order.status.isFinal) return;
      await Future<void>.delayed(pollInterval);
    }
  }
}

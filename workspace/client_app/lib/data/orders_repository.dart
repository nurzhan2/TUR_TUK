import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/content/app_content.dart';
import '../core/demo/demo_data.dart';
import '../core/demo/demo_state.dart';
import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
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
    String? paymentMethod,
    String ifMissing = 'replace',
  });

  Future<Order> repeat(int id);

  /// Живой поток состояния заказа. В демо тикает раз в 4 секунды: двигает
  /// курьера и переключает статус.
  Stream<Order> track(int id);

  /// Оценка доставки 1–5 с отзывом; один раз, только доставленный заказ.
  Future<Order> rate(int id, int rating, {String? comment});
}

class DemoOrdersRepository implements OrdersRepository {
  const DemoOrdersRepository();

  @override
  Future<Order> rate(int id, int rating, {String? comment}) async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.orderById(id).copyWith(rating: rating);
  }

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
    String? paymentMethod,
    String ifMissing = 'replace',
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

  @override
  Future<Order> rate(int id, int rating, {String? comment}) async {
    final body = await _api.post('/orders/$id/rate', body: {
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    }) as Map<String, dynamic>;
    return _withHotelPoint(Order.fromJson(body));
  }

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
    return _withHotelPoint(Order.fromJson(body));
  }

  /// Координат отеля в ответе заказа нет — берём из справочника отелей
  /// (админка), иначе карта трекинга центрировалась бы на точке 0,0.
  Order _withHotelPoint(Order order) {
    if (order.hotelLat != 0 || order.hotelLng != 0) return order;
    final hotel = AppContent.instance.hotelByName(order.hotelName);
    if (hotel == null || (hotel.lat == 0 && hotel.lng == 0)) return order;
    return order.copyWith(hotelLat: hotel.lat, hotelLng: hotel.lng);
  }

  /// Трекинг: статус — опросом раз в 10 с (статусы меняются редко), а
  /// позиция курьера — по WebSocket `/ws/courier-location/{id}` в реальном
  /// времени: курьерское приложение шлёт точку каждые ~5 с / 10 м.
  /// Сокет переподключается сам; при подключении сервер сразу присылает
  /// последнюю известную точку, так что карта не пустая после обрыва.
  @override
  Stream<Order> track(int id) {
    late final StreamController<Order> controller;
    Order? current;
    Timer? poll;
    Timer? reconnect;
    WebSocketChannel? socket;
    var closed = false;

    void emit(Order order) {
      current = order;
      if (!controller.isClosed) controller.add(order);
    }

    Future<void> close() async {
      closed = true;
      poll?.cancel();
      reconnect?.cancel();
      await socket?.sink.close();
      if (!controller.isClosed) await controller.close();
    }

    Future<void> refresh() async {
      try {
        final fresh = await byId(id);
        final prev = current;
        // Статус — с сервера, координаты курьера — последние из сокета.
        emit(prev == null || prev.courierLat == 0
            ? fresh
            : fresh.copyWith(courierLat: prev.courierLat, courierLng: prev.courierLng));
        if (fresh.status.isFinal) await close();
      } catch (_) {
        // Сеть пропала — следующий опрос попробует снова.
      }
    }

    void connect() {
      final token = _api.accessToken;
      if (closed || token == null) return;
      final base = Uri.parse(ApiConfig.baseUrl);
      final uri = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '/ws/courier-location/$id',
        queryParameters: {'token': token},
      );
      void retry() {
        if (closed || reconnect != null) return;
        reconnect = Timer(const Duration(seconds: 5), () {
          reconnect = null;
          connect();
        });
      }

      try {
        final ws = WebSocketChannel.connect(uri);
        socket = ws;
        ws.stream.listen(
          (raw) {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            final lat = (data['lat'] as num?)?.toDouble();
            final lon = (data['lon'] as num?)?.toDouble();
            final order = current;
            if (lat == null || lon == null || order == null) return;
            emit(order.copyWith(courierLat: lat, courierLng: lon));
          },
          onDone: retry,
          onError: (Object _) => retry(),
          cancelOnError: true,
        );
      } catch (_) {
        retry();
      }
    }

    controller = StreamController<Order>(
      onListen: () async {
        await refresh();
        if (closed) return;
        poll = Timer.periodic(pollInterval, (_) => refresh());
        connect();
      },
      onCancel: close,
    );
    return controller.stream;
  }

  @override
  Future<Order> create({
    required String hotelName,
    required String roomNumber,
    String? promoCode,
    String? comment,
    String? paymentMethod,
    String ifMissing = 'replace',
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
      // card | sbp — сервер сохраняет выбор и передаёт его в ЮKassa.
      'payment_method': ?paymentMethod,
      // replace | remove | call — что делать сборщику, если товара нет.
      'if_missing': ifMissing,
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
}

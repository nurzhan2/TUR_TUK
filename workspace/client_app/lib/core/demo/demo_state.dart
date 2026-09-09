import '../../models/cart.dart';
import '../../models/category.dart';
import '../../models/chat_message.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/user_profile.dart';
import 'demo_data.dart';

/// Изменяемое состояние демо-режима: корзина, заказы, чат, вошедший клиент.
///
/// Синглтон, потому что демо обязано ВЕСТИ СЕБЯ КАК ПРИЛОЖЕНИЕ, а не быть
/// набором экранов с картинками: положил товар — бейдж корзины вырос,
/// оформил заказ — он появился в истории, ввёл промокод — итог пересчитался.
/// Разложи это состояние по репозиториям — и каждый экран получит свою
/// корзину, а заказчица увидит ровно ту бутафорию, от которой демо и должно
/// отличаться.
///
/// Всё в памяти и ничего на диске: перезапуск возвращает витрину к исходному
/// виду, и показ можно начать заново, не пересобирая приложение.
class DemoState {
  DemoState._();

  static final DemoState instance = DemoState._();

  final List<Product> _products = DemoData.products();
  final List<CartItem> _cartItems = [];
  final List<Order> _orders = DemoData.orders();
  final List<ChatMessage> _chat = [];

  int _nextCartItemId = 1;
  int _nextOrderId = 1046;
  int _nextMessageId = 1;

  UserProfile? _user;

  /// Телефон, на который «отправлен» код. Хранится, чтобы экран ввода кода
  /// показывал тот же номер, который человек только что набрал.
  String? pendingPhone;

  final List<Category> _categories = DemoData.categories();

  List<Category> get categoriesList => List.unmodifiable(_categories);

  List<Product> get products => List.unmodifiable(_products);

  Product product(int id) => _products.firstWhere(
        (product) => product.id == id,
        orElse: () => throw StateError('товар $id не найден в демо-каталоге'),
      );

  // ── Корзина ────────────────────────────────────────────────────────────

  Cart get cart => Cart(
        items: List.unmodifiable(_cartItems),
        total: _cartItems.fold(0.0, (sum, item) => sum + item.lineTotal),
      );

  Cart addToCart(int productId, int qty) {
    final index = _cartItems.indexWhere((item) => item.product.id == productId);
    if (index == -1) {
      _cartItems.add(CartItem(
        id: _nextCartItemId++,
        product: product(productId),
        quantity: qty,
      ));
    } else {
      // Повторное «в корзину» ДОБАВЛЯЕТ количество, а не заводит вторую
      // строку того же товара: две одинаковые позиции в списке выглядят
      // как сбой, и клиент начинает пересчитывать, сколько же он заказал.
      final item = _cartItems[index];
      _cartItems[index] = item.copyWith(quantity: item.quantity + qty);
    }
    return cart;
  }

  Cart setQuantity(int itemId, int qty) {
    final index = _cartItems.indexWhere((item) => item.id == itemId);
    if (index == -1) return cart;
    if (qty <= 0) {
      _cartItems.removeAt(index);
    } else {
      _cartItems[index] = _cartItems[index].copyWith(quantity: qty);
    }
    return cart;
  }

  Cart removeFromCart(int itemId) {
    _cartItems.removeWhere((item) => item.id == itemId);
    return cart;
  }

  Cart clearCart() {
    _cartItems.clear();
    return cart;
  }

  // ── Заказы ─────────────────────────────────────────────────────────────

  /// Новые сверху — в том же порядке, что отдаёт `/orders/history`.
  List<Order> get orders => List.unmodifiable(_orders);

  Order orderById(int id) => _orders.firstWhere(
        (order) => order.id == id,
        orElse: () => throw StateError('заказ $id не найден'),
      );

  /// Оформление заказа из ТЕКУЩЕЙ корзины. Корзина после этого пустеет —
  /// как в настоящем магазине; иначе клиент оформит один и тот же заказ
  /// дважды, просто не заметив.
  Order createOrder({
    required String hotelName,
    required String roomNumber,
    String? promoCode,
    double discount = 0,
  }) {
    final items = [
      for (final item in _cartItems)
        OrderItem(
          productId: item.product.id,
          name: item.product.name,
          price: item.product.price,
          quantity: item.quantity,
          imageAsset: item.product.imageAsset,
        ),
    ];
    final order = DemoData.order(
      id: _nextOrderId++,
      status: OrderStatus.created,
      items: items,
      createdAt: DateTime.now(),
      courierProgress: 0,
      hotelName: hotelName,
      roomNumber: roomNumber,
      promoCode: promoCode,
      discount: discount,
      courierName: 'Мехмет',
    );
    _orders.insert(0, order);
    _cartItems.clear();
    return order;
  }

  /// Повтор заказа: позиции старого кладутся В КОРЗИНУ, а не создают заказ
  /// молча. Клиент должен увидеть чекаут и подтвердить сумму — на бэкенде
  /// повтор умеет выбрасывать недоступные товары
  /// (`RepeatOrderOut.skipped_items`), и подтверждение там нужно по той же
  /// причине: состав повтора может отличаться от исходного заказа.
  Order repeatOrder(int id) {
    final source = orderById(id);
    _cartItems.clear();
    for (final item in source.items) {
      final catalogItem = _products.firstWhere(
        (product) => product.id == item.productId,
        orElse: () => Product(
          id: item.productId,
          name: item.name,
          description: '',
          price: item.price,
          imageAsset: item.imageAsset,
        ),
      );
      if (!catalogItem.isAvailable) continue;
      _cartItems.add(CartItem(
        id: _nextCartItemId++,
        product: catalogItem,
        quantity: item.quantity,
      ));
    }
    return source;
  }

  /// Один шаг демо-трекинга: курьер на 15% ближе к отелю, статус — на
  /// следующую стадию. `null`, если двигать больше нечего.
  Order? advanceTracking(int id) {
    final index = _orders.indexWhere((order) => order.id == id);
    if (index == -1) return null;
    final order = _orders[index];
    if (order.status.isFinal) return null;

    final nextStatus = switch (order.status) {
      OrderStatus.created => OrderStatus.accepted,
      OrderStatus.accepted => OrderStatus.assembling,
      OrderStatus.assembling => OrderStatus.delivering,
      _ => order.status,
    };

    // Курьер выезжает только на стадии «доставляется»: двигать точку по
    // карте, пока заказ ещё собирают на складе, значит показывать неправду.
    final moving = order.status == OrderStatus.delivering;
    final lat = moving
        ? order.courierLat + (order.hotelLat - order.courierLat) * 0.15
        : order.courierLat;
    final lng = moving
        ? order.courierLng + (order.hotelLng - order.courierLng) * 0.15
        : order.courierLng;

    // Доехал — значит доставлен. Порог в градусах, а не «ровно в точке»:
    // шаг в 15% приближает бесконечно, но никогда не совпадает, и заказ
    // без порога остался бы «в пути» навсегда.
    final arrived =
        moving && _closeEnough(lat, lng, order.hotelLat, order.hotelLng);

    final updated = order.copyWith(
      status: arrived ? OrderStatus.delivered : nextStatus,
      courierLat: lat,
      courierLng: lng,
      courierName: order.courierName ?? 'Мехмет',
    );
    _orders[index] = updated;
    return updated;
  }

  /// Радиус «курьер приехал» — 0,0025°, около 280 метров.
  ///
  /// Порог тут не косметика, а следствие арифметики: шаг «15% оставшегося
  /// пути» приближает бесконечно и НИКОГДА не совпадает с точкой отеля.
  /// Без порога заказ висел бы «в пути» вечно, и показ никогда не дошёл бы
  /// до статуса «доставлен» — то есть до самого интересного экрана.
  ///
  /// Взяты именно 280 метров, а не 45: с 45 метрами до доставки уходит
  /// около двух минут реального времени, и ждать их в разговоре с
  /// заказчицей никто не станет. Цифра при этом не выдумана — Rixos
  /// Sungate занимает несколько гектаров, и 280 метров это его же
  /// территория, а не «где-то рядом».
  static bool _closeEnough(double lat, double lng, double toLat, double toLng) {
    return (lat - toLat).abs() < 0.0025 && (lng - toLng).abs() < 0.0025;
  }

  // ── Чат ────────────────────────────────────────────────────────────────

  List<ChatMessage> get chat {
    if (_chat.isEmpty) {
      _chat.add(ChatMessage(
        id: _nextMessageId++,
        text: DemoData.botGreeting,
        isBot: true,
        isMine: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ));
    }
    return List.unmodifiable(_chat);
  }

  ChatMessage addMyMessage(String text) {
    final message = ChatMessage(
      id: _nextMessageId++,
      text: text,
      isBot: false,
      isMine: true,
      createdAt: DateTime.now(),
    );
    _chat.add(message);
    return message;
  }

  /// Ответ бота на реплику. Ни одно ключевое слово не подошло — отвечаем
  /// заглушкой про оператора, а не молчим: тишина в чате читается как
  /// «приложение сломалось».
  ChatMessage addBotReply(String toText) {
    var answer = DemoData.botFallback;
    for (final response in DemoData.botResponses()) {
      if (response.matches(toText)) {
        answer = response.answer;
        break;
      }
    }
    final message = ChatMessage(
      id: _nextMessageId++,
      text: answer,
      isBot: true,
      isMine: false,
      createdAt: DateTime.now(),
    );
    _chat.add(message);
    return message;
  }

  // ── Авторизация ────────────────────────────────────────────────────────

  UserProfile? get user => _user;

  UserProfile signIn([UserProfile? profile]) {
    _user = profile ?? DemoData.profile;
    return _user!;
  }

  void signOut() {
    _user = null;
    pendingPhone = null;
  }

  /// Полный сброс демо к исходному виду — чтобы показ можно было начать
  /// заново, не перезапуская приложение.
  void reset() {
    _cartItems.clear();
    _chat.clear();
    _orders
      ..clear()
      ..addAll(DemoData.orders());
    _nextCartItemId = 1;
    _nextOrderId = 1046;
    _nextMessageId = 1;
    _user = null;
    pendingPhone = null;
  }
}

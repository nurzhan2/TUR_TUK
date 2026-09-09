import '../core/demo/demo_state.dart';
import '../core/network/api_client.dart';
import '../models/cart.dart';
import 'catalog_repository.dart' show kDemoLatency;

/// Корзина. КАЖДЫЙ метод возвращает актуальную [Cart] целиком, а не «ок».
///
/// Так экрану не нужно достраивать состояние у себя: он получает то, что
/// теперь есть на самом деле. Локальная догадка «я добавил, значит стало на
/// один больше» расходится с сервером в первом же случае, когда товар
/// закончился, — и бейдж корзины начинает врать.
abstract class CartRepository {
  Future<Cart> load();

  Future<Cart> add(int productId, {int qty = 1});

  Future<Cart> setQuantity(int itemId, int qty);

  Future<Cart> remove(int itemId);

  Future<Cart> clear();
}

class DemoCartRepository implements CartRepository {
  const DemoCartRepository();

  @override
  Future<Cart> load() async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.cart;
  }

  @override
  Future<Cart> add(int productId, {int qty = 1}) async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.addToCart(productId, qty);
  }

  @override
  Future<Cart> setQuantity(int itemId, int qty) async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.setQuantity(itemId, qty);
  }

  @override
  Future<Cart> remove(int itemId) async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.removeFromCart(itemId);
  }

  @override
  Future<Cart> clear() async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.clearCart();
  }
}

/// Боевая корзина: `GET/POST/PUT/DELETE /cart` (см. `backend/app/api/cart.py`).
///
/// ИЗВЕСТНЫЙ ПРОБЕЛ: общий [ApiClient] взят из `courier_app` как есть — там
/// он умеет только GET и POST, потому что курьеру больше ничего не нужно.
/// Правка количества и удаление позиции ходят на PUT и DELETE, и закрыть их
/// нечем, пока в клиент не добавлены соответствующие методы. Здесь стоит
/// явный отказ с текстом, а не «тихий» обход через POST: молча отправить
/// не тот глагол значит получить 405 в рантайме и искать причину на экране.
/// Демо-режима это не касается — там работает [DemoCartRepository].
class ApiCartRepository implements CartRepository {
  ApiCartRepository(this._api);

  final ApiClient _api;

  @override
  Future<Cart> load() async {
    final body = await _api.get('/cart') as Map<String, dynamic>;
    return Cart.fromJson(body);
  }

  @override
  Future<Cart> add(int productId, {int qty = 1}) async {
    final body = await _api.post(
      '/cart/items',
      body: {'product_id': productId, 'quantity': qty},
    ) as Map<String, dynamic>;
    return Cart.fromJson(body);
  }

  @override
  Future<Cart> setQuantity(int itemId, int qty) async {
    throw UnimplementedError(
      'PUT /cart/items/$itemId: в ApiClient (скопирован из courier_app) '
      'нет метода put — добавьте его перед сборкой с --dart-define=DEMO=false',
    );
  }

  @override
  Future<Cart> remove(int itemId) async {
    throw UnimplementedError(
      'DELETE /cart/items/$itemId: в ApiClient нет метода delete — '
      'добавьте его перед сборкой с --dart-define=DEMO=false',
    );
  }

  @override
  Future<Cart> clear() async {
    throw UnimplementedError(
      'DELETE /cart: в ApiClient нет метода delete — добавьте его перед '
      'сборкой с --dart-define=DEMO=false',
    );
  }
}

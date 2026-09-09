import 'package:flutter/foundation.dart';

import '../core/di.dart';
import '../models/cart.dart';
import 'controller_state.dart';

/// Корзина. Бейдж на нижней навигации смотрит сюда, поэтому контроллер
/// живёт на весь запуск приложения, а не на время экрана корзины.
class CartController extends ChangeNotifier {
  ControllerState state = ControllerState.initial;
  String? errorMessage;

  Cart cart = const Cart();

  int get count => cart.count;

  double get total => cart.total;

  bool get isEmpty => cart.isEmpty;

  Future<void> load() => _run(() => Di.cart.load());

  Future<void> add(int productId, {int qty = 1}) =>
      _run(() => Di.cart.add(productId, qty: qty));

  Future<void> setQuantity(int itemId, int qty) =>
      _run(() => Di.cart.setQuantity(itemId, qty));

  Future<void> remove(int itemId) => _run(() => Di.cart.remove(itemId));

  Future<void> clear() => _run(() => Di.cart.clear());

  /// Сколько штук этого товара уже в корзине — карточка товара показывает
  /// «в корзине, 2» вместо кнопки «в корзину».
  int quantityOf(int productId) {
    for (final item in cart.items) {
      if (item.product.id == productId) return item.quantity;
    }
    return 0;
  }

  /// Общий ход для всех действий: каждое возвращает корзину ЦЕЛИКОМ, и
  /// докручивать состояние у себя не нужно (см. [CartRepository]).
  ///
  /// Состояние `loading` при добавлении товара НЕ выставляется: иначе
  /// весь список каталога на 300 мс уходит в спиннер из-за одной кнопки.
  /// Ошибку показываем, успех просто применяем.
  Future<void> _run(Future<Cart> Function() action) async {
    if (state == ControllerState.initial) {
      state = ControllerState.loading;
      notifyListeners();
    }
    try {
      cart = await action();
      state = ControllerState.loaded;
      errorMessage = null;
    } catch (error) {
      state = ControllerState.error;
      errorMessage = '$error';
    }
    notifyListeners();
  }
}

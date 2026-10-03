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
      _serial(() => Di.cart.add(productId, qty: qty));

  /// «+/−» в корзине: цифра и итог меняются СРАЗУ, запрос уходит следом.
  /// Без этого быстрые нажатия терялись: каждый тап до ответа сервера
  /// отправлял старое количество, и «+» трижды давал +1.
  Future<void> setQuantity(int itemId, int qty) {
    cart = cart.withQuantity(itemId, qty);
    notifyListeners();
    return _serial(() => Di.cart.setQuantity(itemId, qty));
  }

  Future<void> remove(int itemId) => _serial(() => Di.cart.remove(itemId));

  Future<void> clear() => _serial(() => Di.cart.clear());

  /// Изменения корзины выполняются строго по очереди, а ответ сервера
  /// применяется только после ПОСЛЕДНЕГО из них — иначе ответ на второй
  /// тап перерисовал бы цифру назад поверх уже показанного третьего.
  Future<void> _queue = Future<void>.value();
  int _pending = 0;

  Future<void> _serial(Future<Cart> Function() action) {
    _pending++;
    final next = _queue.then((_) async {
      try {
        final result = await action();
        _pending--;
        if (_pending == 0) {
          cart = result;
          state = ControllerState.loaded;
          errorMessage = null;
          notifyListeners();
        }
      } catch (error) {
        _pending--;
        state = ControllerState.error;
        errorMessage = '$error';
        // Оптимистичная цифра могла разойтись с сервером — сверяемся.
        if (_pending == 0) {
          try {
            cart = await Di.cart.load();
          } catch (_) {}
        }
        notifyListeners();
      }
    });
    _queue = next;
    return next;
  }

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

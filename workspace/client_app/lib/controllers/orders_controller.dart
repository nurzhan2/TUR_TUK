import 'package:flutter/foundation.dart';

import '../core/di.dart';
import '../models/order.dart';
import 'controller_state.dart';

class OrdersController extends ChangeNotifier {
  ControllerState state = ControllerState.initial;
  String? errorMessage;

  List<Order> orders = const [];

  /// Заказ, только что оформленный на чекауте. Экран успеха показывает его
  /// номер, и держать это в аргументах маршрута было бы хрупко: возврат
  /// «назад» на экран успеха потерял бы номер.
  Order? lastCreated;

  Future<void> load() async {
    state = ControllerState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      orders = await Di.orders.list();
      state = ControllerState.loaded;
    } catch (error) {
      state = ControllerState.error;
      errorMessage = '$error';
    }
    notifyListeners();
  }

  Order? byId(int id) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  /// Оформление заказа. Возвращает заказ, а не `void`: экран чекаута
  /// сразу уходит на карточку заказа, и ждать перезагрузки списка ему
  /// незачем.
  Future<Order> create({
    required String hotelName,
    required String roomNumber,
    String? promoCode,
    String? comment,
    String? paymentMethod,
    String ifMissing = 'replace',
  }) async {
    try {
      final order = await Di.orders.create(
        hotelName: hotelName,
        roomNumber: roomNumber,
        promoCode: promoCode,
        comment: comment,
        paymentMethod: paymentMethod,
        ifMissing: ifMissing,
      );
      lastCreated = order;
      // Новый заказ кладём в начало списка сразу, не дожидаясь `load()`:
      // список заказов открывается следующим экраном, и пустое место
      // на месте только что оформленного заказа читается как потеря.
      orders = [order, ...orders];
      state = ControllerState.loaded;
      errorMessage = null;
      notifyListeners();
      return order;
    } catch (error) {
      state = ControllerState.error;
      errorMessage = '$error';
      notifyListeners();
      rethrow;
    }
  }

  /// Повтор заказа: в демо позиции складываются в КОРЗИНУ, а не создают
  /// заказ молча (см. `DemoState.repeatOrder`). Экран после этого ведёт
  /// на корзину, и клиент подтверждает состав сам.
  Future<Order> repeat(int id) async {
    try {
      final order = await Di.orders.repeat(id);
      errorMessage = null;
      notifyListeners();
      return order;
    } catch (error) {
      state = ControllerState.error;
      errorMessage = '$error';
      notifyListeners();
      rethrow;
    }
  }

  /// Поток состояния заказа для экрана трекинга. Контроллер его не держит
  /// и не закрывает: подписка живёт ровно столько, сколько живёт экран,
  /// и закрывать её должен тот, кто открыл.
  Stream<Order> track(int id) => Di.orders.track(id);

  /// Применить пришедшее из трекинга состояние к списку — чтобы, вернувшись
  /// назад, клиент увидел актуальный статус, а не тот, что был при загрузке.
  void applyTracked(Order order) {
    final index = orders.indexWhere((item) => item.id == order.id);
    if (index == -1) return;
    final updated = [...orders];
    updated[index] = order;
    orders = updated;
    notifyListeners();
  }
}

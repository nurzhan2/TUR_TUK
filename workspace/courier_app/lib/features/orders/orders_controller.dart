import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'order_model.dart';
import 'orders_repository.dart';

enum OrdersLoadState { initial, loading, loaded, error }

/// Заказы смены и действия над ними.
///
/// Список держится ЦЕЛИКОМ, включая закрытые: экран режет его на три секции
/// («Новые», «В работе», «Выполненные»), и фильтр «только активные», который
/// стоял здесь раньше, делал третью секцию вечно пустой.
class OrdersController extends ChangeNotifier {
  OrdersController(this._repository);

  final OrdersRepository _repository;

  OrdersLoadState state = OrdersLoadState.initial;
  List<Order> orders = const [];
  String? errorMessage;

  /// Идёт ли действие по конкретному заказу. Не общий `isLoading`: кнопка
  /// «Принять» на одной карточке не должна гасить кнопки на остальных, а
  /// спиннер обязан стоять там, куда нажали.
  final Set<int> busy = {};

  List<Order> get newOrders =>
      orders.where((order) => order.isNew).toList(growable: false);

  List<Order> get inProgressOrders =>
      orders.where((order) => order.isInProgress).toList(growable: false);

  List<Order> get completedOrders =>
      orders.where((order) => order.status.isFinal).toList(growable: false);

  Order? byId(int id) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  Future<void> load() async {
    state = OrdersLoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      orders = await _repository.fetchOrders();
      state = OrdersLoadState.loaded;
    } on ApiException catch (e) {
      errorMessage = e.detail;
      state = OrdersLoadState.error;
    } catch (_) {
      errorMessage = 'network_error';
      state = OrdersLoadState.error;
    }
    notifyListeners();
  }

  Future<bool> accept(int id) => _act(id, () => _repository.accept(id));

  Future<bool> reject(int id) => _act(id, () => _repository.reject(id));

  Future<bool> advance(int id) => _act(id, () => _repository.advance(id));

  Future<bool> confirmDelivery(int id, {required String photoAsset}) =>
      _act(id, () => _repository.confirmDelivery(id, photoAsset: photoAsset));

  /// Общий обвес действия: занятость по заказу, замена строки в списке,
  /// ошибка текстом для экрана.
  ///
  /// Список НЕ перезапрашивается: репозиторий вернул обновлённый заказ, и
  /// подменить одну строку дешевле и спокойнее для глаза, чем перерисовать
  /// весь экран с прыжком скролла.
  Future<bool> _act(int id, Future<Order> Function() action) async {
    busy.add(id);
    errorMessage = null;
    notifyListeners();
    try {
      final updated = await action();
      orders = [
        for (final order in orders)
          if (order.id == updated.id) updated else order,
      ];
      return true;
    } on ApiException catch (e) {
      errorMessage = e.detail;
      return false;
    } catch (_) {
      errorMessage = 'network_error';
      return false;
    } finally {
      busy.remove(id);
      notifyListeners();
    }
  }
}

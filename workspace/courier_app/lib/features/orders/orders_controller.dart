import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'order_model.dart';
import 'orders_repository.dart';

enum OrdersLoadState { initial, loading, loaded, error }

class OrdersController extends ChangeNotifier {
  OrdersController({required OrdersRepository repository}) : _repository = repository;

  final OrdersRepository _repository;

  OrdersLoadState state = OrdersLoadState.initial;
  List<Order> orders = const [];
  String? errorMessage;

  Future<void> load() async {
    state = OrdersLoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final all = await _repository.fetchOrders();
      orders = all.where((order) => order.isActive).toList();
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
}

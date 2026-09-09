import '../../core/network/api_client.dart';
import 'order_model.dart';

/// `GET /orders` — бэкенд уже фильтрует список по `courier_id == текущий
/// пользователь` для роли `courier` (см. `backend/app/api/orders.py`), так
/// что репозиторию не нужно передавать никаких параметров.
class OrdersRepository {
  OrdersRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<Order>> fetchOrders() async {
    final json = await _apiClient.get('/orders') as List<dynamic>;
    return json.map((item) => Order.fromJson(item as Map<String, dynamic>)).toList();
  }
}

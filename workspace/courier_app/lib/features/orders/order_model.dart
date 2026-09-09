/// Статусы заказа — те же значения, что `OrderStatus` в
/// `backend/app/models/order.py`.
enum OrderStatus { created, accepted, assembling, delivering, delivered, cancelled }

OrderStatus _statusFromJson(String value) {
  return OrderStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => OrderStatus.created,
  );
}

/// Зеркало `OrderOut` из `backend/app/schemas/order.py`.
class Order {
  const Order({
    required this.id,
    required this.status,
    required this.total,
    required this.hotelName,
    required this.roomNumber,
    required this.courierId,
    required this.deliveryPhotoUrl,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as int,
        status: _statusFromJson(json['status'] as String),
        total: (json['total'] as num).toDouble(),
        hotelName: json['hotel_name'] as String,
        roomNumber: json['room_number'] as String,
        courierId: json['courier_id'] as int?,
        deliveryPhotoUrl: json['delivery_photo_url'] as String?,
      );

  final int id;
  final OrderStatus status;
  final double total;
  final String hotelName;
  final String roomNumber;
  final int? courierId;
  final String? deliveryPhotoUrl;

  /// Заказ, который курьеру ещё имеет смысл смотреть на главном экране —
  /// не финализированный. Бэкенд сегодня возвращает `GET /orders` уже
  /// отфильтрованным по `courier_id == текущий курьер` (см.
  /// `backend/app/api/orders.py`), отдельного пула «новых, ещё не разобранных»
  /// заказов и эндпоинтов принять/отклонить в бэкенде пока нет — см.
  /// `docs/DECISIONS.md`.
  bool get isActive =>
      status != OrderStatus.delivered && status != OrderStatus.cancelled;
}

/// Статусы заказа — те же значения, что `OrderStatus` в
/// `backend/app/models/order.py`.
enum OrderStatus {
  created,
  accepted,
  assembling,
  delivering,
  delivered,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  bool get isFinal =>
      this == OrderStatus.delivered || this == OrderStatus.cancelled;

  /// Куда заказ движется дальше по рабочему процессу курьера. `null` —
  /// дальше двигать нечего: либо заказ ещё не принят (это отдельное
  /// решение, а не «следующий шаг»), либо он уже закрыт.
  OrderStatus? get next => switch (this) {
    OrderStatus.accepted => OrderStatus.assembling,
    OrderStatus.assembling => OrderStatus.delivering,
    OrderStatus.delivering => OrderStatus.delivered,
    _ => null,
  };
}

/// Позиция заказа. Бэкенд её в `GET /orders` пока не отдаёт (`OrderOut`
/// содержит только суммы и адрес), поэтому в боевом режиме список выходит
/// пустым и экран честно показывает, что состава нет, — а не выдуманные
/// товары. В демо позиции есть.
class OrderItem {
  const OrderItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    name: json['name'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    quantity: json['quantity'] as int? ?? 1,
  );

  final String name;
  final double price;
  final int quantity;

  double get lineTotal => price * quantity;
}

/// Заказ в курьерском приложении.
///
/// Надмножество `OrderOut` из `backend/app/schemas/order.py`: имя и телефон
/// клиента, состав и координаты бэкенд сегодня не отдаёт, но курьеру они
/// нужны — по телефону он звонит, по координатам едет. В боевом режиме
/// незаполненные поля остаются пустыми, а экран их прячет; выдумывать
/// значения нельзя, курьер по ним поедет.
class Order {
  const Order({
    required this.id,
    required this.status,
    required this.total,
    required this.hotelName,
    required this.roomNumber,
    required this.createdAt,
    this.items = const [],
    this.clientName = '',
    this.clientPhone = '',
    this.courierId,
    this.deliveryPhotoAsset,
    this.hotelLat = kemerLat,
    this.hotelLng = kemerLng,
    this.courierLat = depotLat,
    this.courierLng = depotLng,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as int,
    status: _statusFromJson(json['status'] as String),
    total: (json['total'] as num).toDouble(),
    hotelName: json['hotel_name'] as String,
    roomNumber: json['room_number'] as String,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
    items: [
      for (final item in (json['items'] as List<dynamic>? ?? const []))
        OrderItem.fromJson(item as Map<String, dynamic>),
    ],
    clientName: json['client_name'] as String? ?? '',
    clientPhone: json['client_phone'] as String? ?? '',
    courierId: json['courier_id'] as int?,
    deliveryPhotoAsset: json['delivery_photo_url'] as String?,
  );

  /// Центр Кемера и склад TUR TUK: значения по умолчанию для заказов, у
  /// которых координат нет. Без них карта открывалась бы в Атлантике
  /// (нули широты и долготы) — а это читается как поломка, а не как
  /// «данных нет».
  static const double kemerLat = 36.6021;
  static const double kemerLng = 30.5595;
  static const double depotLat = 36.5906;
  static const double depotLng = 30.5710;

  final int id;
  final OrderStatus status;
  final double total;
  final String hotelName;
  final String roomNumber;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String clientName;
  final String clientPhone;
  final int? courierId;
  final String? deliveryPhotoAsset;
  final double hotelLat;
  final double hotelLng;
  final double courierLat;
  final double courierLng;

  /// Новый заказ: создан и ещё никем не взят. Именно пара условий, а не один
  /// статус: заказ со статусом `created`, но уже назначенным курьером, в
  /// общий пул «новых» попадать не должен — его кто-то уже взял.
  bool get isNew => status == OrderStatus.created && courierId == null;

  bool get isInProgress => !isNew && !status.isFinal;

  int get itemsCount => items.fold(0, (sum, item) => sum + item.quantity);

  Order copyWith({
    OrderStatus? status,
    int? courierId,
    String? deliveryPhotoAsset,
    double? courierLat,
    double? courierLng,
  }) {
    return Order(
      id: id,
      status: status ?? this.status,
      total: total,
      hotelName: hotelName,
      roomNumber: roomNumber,
      createdAt: createdAt,
      items: items,
      clientName: clientName,
      clientPhone: clientPhone,
      courierId: courierId ?? this.courierId,
      deliveryPhotoAsset: deliveryPhotoAsset ?? this.deliveryPhotoAsset,
      hotelLat: hotelLat,
      hotelLng: hotelLng,
      courierLat: courierLat ?? this.courierLat,
      courierLng: courierLng ?? this.courierLng,
    );
  }
}

OrderStatus _statusFromJson(String value) {
  return OrderStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => OrderStatus.created,
  );
}

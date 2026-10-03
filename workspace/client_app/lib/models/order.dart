/// Стадии заказа. Порядок значений — это порядок жизненного цикла, на нём
/// держится и таймлайн в трекинге, и переключение статуса в демо-потоке.
enum OrderStatus {
  created,
  accepted,
  assembling,
  delivering,
  delivered,
  cancelled;

  static OrderStatus fromJson(String? raw) {
    final value = (raw ?? '').toLowerCase();
    return OrderStatus.values.firstWhere(
      (status) => status.name == value,
      // Незнакомый статус НЕ считаем отменой: бэкенд может завести новый,
      // а показать заказ как отменённый — соврать клиенту. `created` —
      // самая безобидная трактовка: заказ есть, стадия неизвестна.
      orElse: () => OrderStatus.created,
    );
  }

  /// Заказ доехал или отменён — по нему больше ничего не будет двигаться.
  bool get isFinal => this == OrderStatus.delivered || this == OrderStatus.cancelled;

  /// Место в таймлайне: отменённый заказ в шкале прогресса не участвует.
  int get step => switch (this) {
        OrderStatus.created => 0,
        OrderStatus.accepted => 1,
        OrderStatus.assembling => 2,
        OrderStatus.delivering => 3,
        OrderStatus.delivered => 4,
        OrderStatus.cancelled => -1,
      };
}

/// Позиция заказа — СНИМОК: имя и цена сохранены на момент оформления
/// (тот же принцип, что у `OrderItem.price` на бэкенде). Если товар потом
/// подорожает, история заказа не должна переписываться задним числом.
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageAsset = '',
  });

  final int productId;
  final String name;
  final double price;
  final int quantity;
  final String imageAsset;

  double get lineTotal => price * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productId: json['product_id'] as int,
        name: (json['product_name'] ?? json['name'] ?? '') as String,
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int,
        imageAsset: (json['photo_url'] as String?) ?? '',
      );
}

class Order {
  const Order({
    required this.id,
    required this.status,
    required this.total,
    required this.hotelName,
    required this.roomNumber,
    required this.createdAt,
    this.discount = 0,
    this.deliveryFee = 0,
    this.items = const [],
    this.courierName,
    this.promoCode,
    this.deliveryPhotoAsset,
    this.hotelLat = 0,
    this.hotelLng = 0,
    this.courierLat = 0,
    this.courierLng = 0,
  });

  final int id;
  final OrderStatus status;
  final double total;
  final double discount;
  final double deliveryFee;
  final String hotelName;
  final String roomNumber;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String? courierName;
  final String? promoCode;
  final String? deliveryPhotoAsset;
  final double hotelLat;
  final double hotelLng;
  final double courierLat;
  final double courierLng;

  /// Сумма позиций ДО скидки и доставки. Считается из позиций, а не хранится
  /// отдельным полем: два источника одного числа однажды разойдутся.
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.lineTotal);

  Order copyWith({
    OrderStatus? status,
    double? courierLat,
    double? courierLng,
    String? courierName,
    double? hotelLat,
    double? hotelLng,
  }) {
    return Order(
      id: id,
      status: status ?? this.status,
      total: total,
      discount: discount,
      deliveryFee: deliveryFee,
      hotelName: hotelName,
      roomNumber: roomNumber,
      createdAt: createdAt,
      items: items,
      courierName: courierName ?? this.courierName,
      promoCode: promoCode,
      deliveryPhotoAsset: deliveryPhotoAsset,
      hotelLat: hotelLat ?? this.hotelLat,
      hotelLng: hotelLng ?? this.hotelLng,
      courierLat: courierLat ?? this.courierLat,
      courierLng: courierLng ?? this.courierLng,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as int,
        status: OrderStatus.fromJson(json['status'] as String?),
        total: (json['total'] as num).toDouble(),
        discount: (json['discount'] as num?)?.toDouble() ?? 0,
        deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
        hotelName: (json['hotel_name'] as String?) ?? '',
        roomNumber: (json['room_number'] as String?) ?? '',
        // `OrderOut` без `created_at` (его отдаёт только `/orders/history`) —
        // не повод падать: для списка достаточно самого заказа.
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.now(),
        items: [
          for (final item in (json['items'] as List? ?? const []))
            OrderItem.fromJson(item as Map<String, dynamic>),
        ],
        courierName: json['courier_name'] as String?,
        promoCode: json['promo_code'] as String?,
        deliveryPhotoAsset: json['delivery_photo_url'] as String?,
        hotelLat: (json['hotel_lat'] as num?)?.toDouble() ?? 0,
        hotelLng: (json['hotel_lon'] as num?)?.toDouble() ?? 0,
        courierLat: (json['courier_lat'] as num?)?.toDouble() ?? 0,
        courierLng: (json['courier_lon'] as num?)?.toDouble() ?? 0,
      );
}

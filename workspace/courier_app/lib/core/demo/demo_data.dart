import '../../features/orders/order_model.dart';

/// Демо-данные курьерского приложения.
///
/// Пять заказов, разложенных по всем трём секциям списка: два новых, один
/// на сборке, один в пути, один доставленный. Состав подобран так, чтобы
/// на экране было что читать — суммы разные, отели разные, позиции
/// правдоподобные; витрина с пятью одинаковыми заказами по 3 000 ₽
/// выглядит как заглушка, а не как рабочий день курьера.
class DemoData {
  const DemoData._();

  /// Курьер, под которым идёт показ. Заказы, назначенные ему, — те, что
  /// в работе; у новых `courierId` пуст, их ещё никто не взял.
  static const int courierId = 7;
  static const String courierName = 'Мехмет';
  static const String courierPhone = '+90 555 210-33-18';

  /// Фотография коробки на экране подтверждения доставки. Камеры в демо нет,
  /// снимок подставной — тот же файл, что показывает клиентское приложение
  /// в карточке доставленного заказа.
  static const String boxPhoto = 'assets/demo/box01.jpg';

  /// Координаты отелей Кемера. Взяты по центрам территорий, с точностью до
  /// сотых минуты: курьеру нужен ориентир на карте, а не геодезия.
  static const Map<String, (double, double)> hotels = {
    'Rixos Sungate': (36.5764, 30.5386),
    'Club Med Palmiye': (36.5851, 30.5501),
    'Maxx Royal Kemer': (36.6402, 30.5187),
    'Amara Prestige': (36.6019, 30.5628),
    'Crystal Sunset Luxury': (36.5688, 30.5312),
    'Orange County Kemer': (36.6055, 30.5644),
    'Akra Kemer': (36.5972, 30.5589),
    'Sherwood Exclusive Kemer': (36.5820, 30.5455),
  };

  static (double, double) hotelPoint(String hotel) =>
      hotels[hotel] ?? (Order.kemerLat, Order.kemerLng);

  static List<Order> orders() {
    final now = DateTime.now();

    return [
      // ── Новые: не назначены никому ────────────────────────────────────
      _order(
        id: 1051,
        status: OrderStatus.created,
        createdAt: now.subtract(const Duration(minutes: 6)),
        hotel: 'Amara Prestige',
        room: '318',
        clientName: 'Ольга Величко',
        clientPhone: '+7 916 442-18-05',
        items: const [
          OrderItem(name: 'Турецкий кофе Mehmet Efendi, 250 г', price: 420, quantity: 2),
          OrderItem(name: 'Пахлава с грецким орехом, 500 г', price: 1150, quantity: 1),
          OrderItem(name: 'Гранатовый сок, 1 л', price: 390, quantity: 3),
        ],
      ),
      _order(
        id: 1052,
        status: OrderStatus.created,
        createdAt: now.subtract(const Duration(minutes: 2)),
        hotel: 'Maxx Royal Kemer',
        room: '1204',
        clientName: 'Дмитрий Соколов',
        clientPhone: '+7 903 771-60-42',
        items: const [
          OrderItem(name: 'Оливковое масло Komili, 1 л', price: 890, quantity: 1),
          OrderItem(name: 'Набор лукума, 800 г', price: 1340, quantity: 2),
          OrderItem(name: 'Крем для рук с оливой', price: 260, quantity: 4),
          OrderItem(name: 'Полотенце пештемаль', price: 1480, quantity: 1),
        ],
      ),

      // ── В работе: назначены курьеру показа ────────────────────────────
      _order(
        id: 1049,
        status: OrderStatus.assembling,
        createdAt: now.subtract(const Duration(minutes: 34)),
        hotel: 'Rixos Sungate',
        room: '412',
        clientName: 'Анастасия Ким',
        clientPhone: '+7 999 123-45-67',
        courierId: courierId,
        items: const [
          OrderItem(name: 'Розовое масло Isparta, 20 мл', price: 2100, quantity: 1),
          OrderItem(name: 'Мыло с оливковым маслом, 3 шт', price: 540, quantity: 2),
          OrderItem(name: 'Чай яблочный, 400 г', price: 310, quantity: 2),
        ],
      ),
      _order(
        id: 1047,
        status: OrderStatus.delivering,
        createdAt: now.subtract(const Duration(minutes: 58)),
        hotel: 'Orange County Kemer',
        room: '806',
        clientName: 'Марина Гусева',
        clientPhone: '+7 921 305-77-19',
        courierId: courierId,
        // Курьер уже в пути: точка сдвинута примерно на две трети маршрута,
        // иначе на карте он стоял бы на складе, хотя статус говорит «везу».
        courierAt: (36.5998, 30.5661),
        items: const [
          OrderItem(name: 'Сушёный инжир, 1 кг', price: 720, quantity: 1),
          OrderItem(name: 'Фисташки Antep, 500 г', price: 1680, quantity: 1),
          OrderItem(name: 'Гель для душа с гранатом', price: 340, quantity: 2),
        ],
      ),

      // ── Выполненные ───────────────────────────────────────────────────
      _order(
        id: 1044,
        status: OrderStatus.delivered,
        createdAt: now.subtract(const Duration(hours: 4, minutes: 12)),
        hotel: 'Akra Kemer',
        room: '507',
        clientName: 'Сергей Литвинов',
        clientPhone: '+7 985 640-22-90',
        courierId: courierId,
        deliveryPhotoAsset: boxPhoto,
        items: const [
          OrderItem(name: 'Набор специй, 6 банок', price: 980, quantity: 1),
          OrderItem(name: 'Мёд каштановый, 850 г', price: 1420, quantity: 1),
        ],
      ),
    ];
  }

  /// Сборка заказа: сумма считается ПО ПОЗИЦИЯМ, а не задаётся руками.
  /// Разошедшиеся «итого» и состав — первое, что заметит курьер, и он
  /// справедливо перестанет верить экрану.
  static Order _order({
    required int id,
    required OrderStatus status,
    required DateTime createdAt,
    required String hotel,
    required String room,
    required String clientName,
    required String clientPhone,
    required List<OrderItem> items,
    int? courierId,
    String? deliveryPhotoAsset,
    (double, double)? courierAt,
  }) {
    final hotelPoint = DemoData.hotelPoint(hotel);
    final courierPoint = courierAt ?? (Order.depotLat, Order.depotLng);

    return Order(
      id: id,
      status: status,
      total: items.fold(0.0, (sum, item) => sum + item.lineTotal),
      hotelName: hotel,
      roomNumber: room,
      createdAt: createdAt,
      items: items,
      clientName: clientName,
      clientPhone: clientPhone,
      courierId: courierId,
      deliveryPhotoAsset: deliveryPhotoAsset,
      hotelLat: hotelPoint.$1,
      hotelLng: hotelPoint.$2,
      courierLat: courierPoint.$1,
      courierLng: courierPoint.$2,
    );
  }
}

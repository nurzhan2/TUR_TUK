import '../../features/orders/order_model.dart';
import 'demo_data.dart';

/// Изменяемое состояние демо: список заказов и вошедший курьер.
///
/// Синглтон по той же причине, что в клиентском приложении: демо обязано
/// вести себя как приложение, а не быть набором картинок. Принял заказ — он
/// уехал из «Новых» в «В работе»; довёл до «Доставлен» — попал в
/// «Выполненные» вместе с фотографией коробки. Разложи это состояние по
/// репозиториям, и каждый экран получит свой список заказов.
///
/// Всё в памяти: перезапуск возвращает смену курьера к началу, и показ
/// можно провести заново, не пересобирая приложение.
class DemoState {
  DemoState._();

  static final DemoState instance = DemoState._();

  final List<Order> _orders = DemoData.orders();

  bool _signedIn = false;

  /// Телефон, на который «отправлен» код: экран ввода кода показывает тот
  /// номер, который курьер только что набрал.
  String? pendingPhone;

  bool get signedIn => _signedIn;

  /// Порядок: сначала новые, потом в работе, потом закрытые, внутри групп —
  /// свежие сверху. Сортировка живёт ЗДЕСЬ, а не на экране: секции считает
  /// экран, но их наполнение не должно зависеть от того, в каком порядке
  /// репозиторий отдал список.
  List<Order> get orders {
    final sorted = [..._orders];
    sorted.sort((a, b) {
      final rank = _rank(a).compareTo(_rank(b));
      if (rank != 0) return rank;
      return b.createdAt.compareTo(a.createdAt);
    });
    return List.unmodifiable(sorted);
  }

  static int _rank(Order order) {
    if (order.isNew) return 0;
    if (order.status.isFinal) return 2;
    return 1;
  }

  Order byId(int id) => _orders.firstWhere(
    (order) => order.id == id,
    orElse: () => throw StateError('заказ $id не найден в демо-данных'),
  );

  /// Принять заказ: он назначается курьеру показа и переходит в `accepted`.
  Order accept(int id) => _replace(
    id,
    (order) =>
        order.copyWith(status: OrderStatus.accepted, courierId: DemoData.courierId),
  );

  /// Отклонить заказ. Уходит в `cancelled`, а не исчезает из списка: заказ,
  /// пропавший с экрана без следа, читается как потерянный, и курьер идёт
  /// проверять, не отменил ли он лишнее.
  Order reject(int id) =>
      _replace(id, (order) => order.copyWith(status: OrderStatus.cancelled));

  /// Следующий шаг рабочего процесса. Куда именно — решает модель
  /// (`OrderStatusX.next`), чтобы порядок стадий был описан один раз.
  Order advance(int id) => _replace(id, (order) {
    final next = order.status.next;
    if (next == null) return order;
    // Выехал — значит поехал: точку курьера сдвигаем со склада на маршрут,
    // иначе на карте он стоит на месте с надписью «в пути».
    if (next == OrderStatus.delivering) {
      return order.copyWith(
        status: next,
        courierLat: order.courierLat + (order.hotelLat - order.courierLat) * 0.4,
        courierLng: order.courierLng + (order.hotelLng - order.courierLng) * 0.4,
      );
    }
    return order.copyWith(status: next);
  });

  /// Доставлено: заказ закрывается вместе со снимком коробки, а курьер
  /// оказывается у отеля — он же только что отдал заказ на рецепции.
  Order confirmDelivery(int id, {required String photoAsset}) => _replace(
    id,
    (order) => order.copyWith(
      status: OrderStatus.delivered,
      deliveryPhotoAsset: photoAsset,
      courierLat: order.hotelLat,
      courierLng: order.hotelLng,
    ),
  );

  Order _replace(int id, Order Function(Order) change) {
    final index = _orders.indexWhere((order) => order.id == id);
    if (index == -1) throw StateError('заказ $id не найден в демо-данных');
    final updated = change(_orders[index]);
    _orders[index] = updated;
    return updated;
  }

  // ── Авторизация ──────────────────────────────────────────────────────

  void signIn() => _signedIn = true;

  void signOut() {
    _signedIn = false;
    pendingPhone = null;
  }
}

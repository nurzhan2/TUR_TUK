import '../../models/category.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/user_profile.dart';
import '../content/app_content.dart';

/// Содержимое демо-режима: каталог, заказы, промокоды, ответы бота.
///
/// Всё здесь — ЛИТЕРАЛЫ, а не генерация из шаблона: заказчице показывают
/// приложение, и «Товар 17» на витрине выглядит как незаконченная работа,
/// даже если механика под ним рабочая. Тексты правдоподобны для Кемера:
/// то, что действительно возят в отели.
///
/// Каталог и заказы отдаются ФУНКЦИЯМИ, а не константами: демо-состояние
/// ([DemoState]) меняет заказы и корзину, и общий изменяемый список сломал
/// бы «начать сначала» — каждый сброс должен получать свежую копию.
class DemoData {
  const DemoData._();

  /// Суммы доставки приходят из настроек (`content/settings.json`): их
  /// правит заказчица, а не разработчик. Значения по умолчанию совпадают с
  /// тем, что она называла в переписке.
  static double get minOrderTotal => AppContent.instance.delivery.minOrderTotal;
  static double get deliveryFee => AppContent.instance.delivery.deliveryFee;
  static double get freeDeliveryFrom =>
      AppContent.instance.delivery.freeDeliveryFrom;

  /// Координаты отеля гостьи и склада — из настроек: отели заводятся в
  /// `content/hotels.json`, склад в `content/settings.json`.
  static double get hotelLat =>
      AppContent.instance.hotelByName(profile.hotelName)?.lat ??
      AppContent.instance.hotels.first.lat;
  static double get hotelLng =>
      AppContent.instance.hotelByName(profile.hotelName)?.lng ??
      AppContent.instance.hotels.first.lng;
  static double get courierStartLat => AppContent.instance.warehouse.lat;
  static double get courierStartLng => AppContent.instance.warehouse.lng;

  static const UserProfile profile = UserProfile(
    name: 'Анастасия',
    phone: '+7 999 123-45-67',
    hotelName: 'Rixos Sungate',
    roomNumber: '412',
  );

  /// Каталог берётся из настроек: категории и товары заводит заказчица в
  /// `content/catalog.json`, фотографии кладёт в `content/photos`. В коде
  /// не осталось ни одного товара — прислала новый прайс, применили
  /// скриптом `tools/apply_content.py`, пересобрали.
  static List<Category> categories() => AppContent.instance.categories;

  static List<Product> products() => AppContent.instance.products;


  /// Промокоды демо. `EXPIRED` заведён НАРОЧНО просроченным: экран чекаута
  /// обязан показывать и неудачу тоже, а проверить её иначе нечем.
  static List<DemoPromo> promos() => [
        // Промокоды приходят из настроек (`content/settings.json`), чтобы
        // заказчица заводила акции сама, не трогая код. `expired` — это
        // выключенный код: чекаут обязан показывать и неудачу тоже.
        for (final promo in AppContent.instance.promoCodes)
          DemoPromo(
            code: promo.code,
            percent: promo.type == 'percent' ? promo.value : 0,
            amount: promo.type == 'fixed' ? promo.value : 0,
            expired: !promo.active,
          ),
      ];

  /// Ответы чат-бота — те же тексты, что в seed-миграции бэкенда
  /// `53fad0634450_chat_websocket_bot_responses.py`. Расхождение здесь
  /// означало бы, что демо обещает клиенту не то, что скажет живой бот.
  static List<DemoBotResponse> botResponses() => const [
        DemoBotResponse(
          keywords: 'минимальная сумма,минимальный заказ,от какой суммы,сколько минимум',
          answer: 'Минимальная сумма заказа — 3000 ₽.',
        ),
        DemoBotResponse(
          keywords: 'оплата,как оплатить,способ оплаты,картой,сбп',
          answer: 'Оплата принимается только онлайн: банковской картой или через СБП, '
              'в рублях. Наличные не принимаются.',
        ),
        DemoBotResponse(
          keywords: 'доставка,когда привезут,время доставки,сколько ждать',
          answer: 'Курьер доставит заказ на рецепцию вашего отеля. Отследить статус '
              'можно в приложении в разделе «Мои заказы».',
        ),
        DemoBotResponse(
          keywords: 'как получить заказ,забрать заказ,получение заказа,рецепция',
          answer: 'Заказ можно забрать на рецепции отеля, назвав номер заказа или '
              'последние 4 цифры номера телефона.',
        ),
        DemoBotResponse(
          keywords: 'зона доставки,куда доставляете,какие отели,список отелей',
          answer: 'Мы доставляем только по отелям и гостиницам Кемера из списка '
              'в приложении. Если вашего отеля нет в списке — уточните у оператора.',
        ),
        DemoBotResponse(
          keywords: 'статус заказа,где мой заказ,отследить заказ',
          answer: 'Статус заказа отображается в разделе «Мои заказы»: принят, '
              'на сборке, доставляется, доставлен.',
        ),
        DemoBotResponse(
          keywords: 'промокод,скидка',
          answer: 'Промокод можно ввести при оформлении заказа в корзине.',
        ),
        DemoBotResponse(
          keywords: 'язык,на английском,на турецком,change language',
          answer: 'Язык приложения можно поменять в настройках профиля: русский, '
              'английский или турецкий.',
        ),
      ];

  /// Ответ бота на реплику, которая ни во что не попала. Молчание в чате
  /// читается как «приложение сломалось», поэтому ответ есть всегда.
  static const String botFallback =
      'Я передал вопрос оператору — он ответит в ближайшее время. '
      'А пока могу рассказать про доставку, оплату, промокоды и зону доставки.';

  static const String botGreeting =
      'Здравствуйте! Я бот TUR TUK. Могу рассказать про доставку, оплату '
      'и промокоды, а сложный вопрос передам оператору. Чем помочь?';

  /// Четыре заказа для истории: один доставлен (с фото коробки), один в пути,
  /// один собирается, один только что создан.
  ///
  /// Даты считаются ОТ СЕГОДНЯШНЕГО ДНЯ, а не зашиты литералом: демо
  /// показывают через недели после сборки, и «2 дня назад» должно
  /// оставаться правдой, а не превращаться в прошлогоднюю дату.
  static List<Order> orders() {
    final now = DateTime.now();
    final catalog = {for (final product in products()) product.id: product};

    OrderItem line(int productId, int quantity) {
      final product = catalog[productId]!;
      return OrderItem(
        productId: product.id,
        name: product.name,
        price: product.price,
        quantity: quantity,
        imageAsset: product.imageAsset,
      );
    }

    return [
      order(
        id: 1045,
        status: OrderStatus.created,
        items: [line(3, 1), line(15, 1)],
        createdAt: now.subtract(const Duration(minutes: 4)),
        courierProgress: 0,
      ),
      order(
        id: 1044,
        status: OrderStatus.assembling,
        items: [line(26, 2), line(6, 3), line(18, 1)],
        createdAt: now.subtract(const Duration(minutes: 26)),
        courierProgress: 0,
      ),
      order(
        id: 1043,
        status: OrderStatus.delivering,
        items: [line(22, 1), line(11, 1), line(27, 1)],
        createdAt: now.subtract(const Duration(hours: 1, minutes: 10)),
        courierName: 'Мехмет',
        promoCode: 'KEMER10',
        discount: 682,
        courierProgress: 0.55,
      ),
      order(
        id: 1042,
        status: OrderStatus.delivered,
        items: [line(21, 2), line(16, 1), line(4, 1)],
        createdAt: now.subtract(const Duration(days: 2, hours: 3)),
        courierName: 'Ахмет',
        deliveryPhotoAsset: 'assets/demo/box01.jpg',
        courierProgress: 1,
      ),
    ];
  }

  /// Сборка заказа из позиций. Итог НЕ проставляется руками: иначе демо
  /// однажды покажет сумму, не сходящуюся со списком товаров, — а именно
  /// туда заказчица и посмотрит в первую очередь.
  static Order order({
    required int id,
    required OrderStatus status,
    required List<OrderItem> items,
    required DateTime createdAt,
    required double courierProgress,
    String? hotelName,
    String? roomNumber,
    String? courierName,
    String? promoCode,
    double discount = 0,
    String? deliveryPhotoAsset,
  }) {
    final subtotal = items.fold(0.0, (sum, item) => sum + item.lineTotal);
    // Доставка бесплатна от 5000 ₽ — то же правило, что показывает воронка
    // на корзине и чекауте. Без него итог в списке заказов расходился бы
    // с суммой, которую гостья только что видела на кнопке «Оплатить».
    final delivery = subtotal >= freeDeliveryFrom ? 0.0 : deliveryFee;
    return Order(
      id: id,
      status: status,
      total: subtotal - discount + delivery,
      discount: discount,
      deliveryFee: delivery,
      // Значением по умолчанию поле const-объекта быть не может, поэтому
      // подстановка отеля гостьи стоит здесь, а не в сигнатуре.
      hotelName: hotelName ?? profile.hotelName,
      roomNumber: roomNumber ?? profile.roomNumber,
      createdAt: createdAt,
      items: items,
      courierName: courierName,
      promoCode: promoCode,
      deliveryPhotoAsset: deliveryPhotoAsset,
      hotelLat: hotelLat,
      hotelLng: hotelLng,
      courierLat: courierStartLat + (hotelLat - courierStartLat) * courierProgress,
      courierLng: courierStartLng + (hotelLng - courierStartLng) * courierProgress,
    );
  }
}

/// Промокод демо-режима. Проценты и фиксированная сумма — взаимоисключающие
/// поля, поэтому оба необязательны, а скидку считает [discountFor].
class DemoPromo {
  const DemoPromo({
    required this.code,
    this.percent = 0,
    this.amount = 0,
    this.expired = false,
  });

  final String code;
  final double percent;
  final double amount;
  final bool expired;

  /// Скидка НИКОГДА не больше суммы корзины: «−500 ₽» на корзину в 300 ₽
  /// иначе даёт отрицательный итог, и клиент видит, что магазин должен ему.
  double discountFor(double cartTotal) {
    final raw = percent > 0 ? cartTotal * percent / 100 : amount;
    return raw > cartTotal ? cartTotal : raw;
  }
}

class DemoBotResponse {
  const DemoBotResponse({required this.keywords, required this.answer});

  final String keywords;
  final String answer;

  /// Сравнение по вхождению подстроки — ровно как на бэкенде
  /// (`app/routers/chat.py`), чтобы демо и живой бот отвечали одинаково.
  bool matches(String text) {
    final lower = text.toLowerCase();
    return keywords.split(',').any((keyword) {
      final trimmed = keyword.trim();
      return trimmed.isNotEmpty && lower.contains(trimmed);
    });
  }
}

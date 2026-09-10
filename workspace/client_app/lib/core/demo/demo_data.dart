import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/user_profile.dart';

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

  /// Минимальная сумма заказа — 3000 ₽ (ответ бота из seed-миграции
  /// 53fad0634450, чтобы витрина и чат не расходились в цифрах).
  static const double minOrderTotal = 3000;
  static const double deliveryFee = 300;
  /// Порог бесплатной доставки. Дублируется в `CartTotals` (файл другой
  /// сессии); значения обязаны совпадать, иначе воронка и список заказов
  /// покажут разные суммы.
  static const double freeDeliveryFrom = 5000;

  /// Отель гостьи и точка старта курьера — координаты настоящие:
  /// Rixos Sungate на юге Кемера и склад в северной части посёлка.
  static const double hotelLat = 36.5573;
  static const double hotelLng = 30.5495;
  static const double courierStartLat = 36.6021;
  static const double courierStartLng = 30.5619;

  static const UserProfile profile = UserProfile(
    name: 'Анастасия',
    phone: '+7 999 123-45-67',
    hotelName: 'Rixos Sungate',
    roomNumber: '412',
  );

  static List<Category> categories() => const [
        Category(id: 1, name: 'Сувениры', icon: Icons.card_giftcard_outlined),
        Category(id: 2, name: 'Косметика', icon: Icons.spa_outlined),
        Category(id: 3, name: 'Продукты', icon: Icons.shopping_basket_outlined),
        Category(id: 4, name: 'Напитки', icon: Icons.local_cafe_outlined),
        Category(id: 5, name: 'Сладости', icon: Icons.cake_outlined),
        Category(id: 6, name: 'Пляж', icon: Icons.beach_access_outlined),
      ];

  static List<Product> products() => const [
        // ── Сувениры ─────────────────────────────────────────────────────
        Product(
          id: 1,
          categoryId: 1,
          name: 'Магнит «Кемер» ручной работы',
          description:
              'Керамический магнит с видом на пирс и Таврские горы. Расписан вручную '
              'в мастерской в Чамьюва, поэтому двух одинаковых не бывает. '
              'Лёгкий, в чемодане места почти не занимает.',
          price: 350,
          unit: 'шт',
          imageAsset: 'assets/demo/p01.jpg',
        ),
        Product(
          id: 2,
          categoryId: 1,
          name: 'Керамическая тарелка с изникским узором',
          description:
              'Декоративная тарелка 20 см с классическим сине-белым орнаментом Изника. '
              'Расписана и обожжена вручную, подходит и на стену, и под фрукты. '
              'Идёт в подарочной коробке с мягкой прокладкой.',
          price: 1890,
          unit: 'шт',
          imageAsset: 'assets/demo/p02.jpg',
        ),
        Product(
          id: 3,
          categoryId: 1,
          name: 'Набор турецких стаканов для чая, 6 шт',
          description:
              'Шесть стаканов-тюльпанов с блюдцами и ложками — тот самый набор, '
              'из которого чай пьют по всей Турции. Тонкое стекло с золотой каймой. '
              'Упакован в коробку, довезёте без сколов.',
          price: 2450,
          unit: 'набор',
          imageAsset: 'assets/demo/p03.jpg',
        ),
        Product(
          id: 4,
          categoryId: 1,
          name: 'Оберег назар в подарочной коробке',
          description:
              'Стеклянный «глаз от сглаза» диаметром 8 см на кожаном шнурке. '
              'Классический турецкий оберег, который вешают у входа в дом. '
              'Ручная работа, стекло варят в Измире.',
          price: 690,
          oldPrice: 890,
          unit: 'шт',
          imageAsset: 'assets/demo/p04.jpg',
        ),
        Product(
          id: 5,
          categoryId: 1,
          name: 'Медная джезва для кофе',
          description:
              'Джезва на 200 мл из кованой меди с лужёным слоем и деревянной ручкой. '
              'Подходит для газовой плиты и для песка. '
              'С ней кофе получается таким же, как в кофейне на набережной.',
          price: 1650,
          unit: 'шт',
          imageAsset: 'assets/demo/p05.jpg',
        ),

        // ── Косметика ────────────────────────────────────────────────────
        Product(
          id: 6,
          categoryId: 2,
          name: 'Оливковое мыло «Дафна»',
          description:
              'Натуральное мыло на оливковом и лавровом масле, сваренное холодным '
              'способом. Подходит и для тела, и для волос, не сушит кожу после моря. '
              'Одного бруска хватает больше чем на месяц.',
          price: 420,
          unit: '150 г',
          imageAsset: 'assets/demo/p06.jpg',
        ),
        Product(
          id: 7,
          categoryId: 2,
          name: 'Розовая вода Isparta',
          description:
              'Гидролат дамасской розы из Ыспарты — города, где её выращивают на экспорт. '
              'Снимает покраснение после солнца и освежает кожу в жару. '
              'Без спирта и отдушек, состав из одной строки.',
          price: 980,
          unit: '250 мл',
          imageAsset: 'assets/demo/p07.jpg',
        ),
        Product(
          id: 8,
          categoryId: 2,
          name: 'Масло чёрного тмина холодного отжима',
          description:
              'Нерафинированное масло чёрного тмина первого отжима в тёмном стекле. '
              'Принимают и внутрь по чайной ложке, и наносят на кожу. '
              'Вкус резкий — это норма для настоящего сорта.',
          price: 1250,
          unit: '100 мл',
          imageAsset: 'assets/demo/p08.jpg',
        ),
        Product(
          id: 9,
          categoryId: 2,
          name: 'Крем для рук с экстрактом граната',
          description:
              'Плотный питательный крем с гранатовым маслом и витамином E. '
              'Впитывается без липкой плёнки, тюбик помещается в пляжную сумку. '
              'Лёгкий фруктовый запах, без резкой отдушки.',
          price: 560,
          unit: '75 мл',
          imageAsset: 'assets/demo/p09.jpg',
          isAvailable: false,
        ),
        Product(
          id: 10,
          categoryId: 2,
          name: 'Рукавица кесе и мыло для хаммама',
          description:
              'Тот самый набор, которым отшелушивают кожу в турецкой бане: жёсткая '
              'рукавица из шёлковой вискозы плюс оливковое мыло-пена. '
              'Хватает на весь отпуск и ещё останется.',
          price: 740,
          unit: 'набор',
          imageAsset: 'assets/demo/p10.jpg',
        ),

        // ── Продукты ─────────────────────────────────────────────────────
        Product(
          id: 11,
          categoryId: 3,
          name: 'Оливковое масло Extra Virgin, Айвалык',
          description:
              'Нефильтрованное масло первого холодного отжима из региона Айвалык, '
              'кислотность ниже 0,5 процента. Годится и в салат, и просто с хлебом. '
              'В жестяной банке, свет ему не вредит.',
          price: 2350,
          unit: '1 л',
          imageAsset: 'assets/demo/p11.jpg',
        ),
        Product(
          id: 12,
          categoryId: 3,
          name: 'Набор турецких специй, 6 видов',
          description:
              'Сумах, пул бибер, тимьян, зира, смесь для кёфте и чёрный перец '
              'в отдельных банках — ровно то, на чём держится местная кухня. '
              'Банки закручиваются плотно, в багаже не просыпятся.',
          price: 890,
          oldPrice: 1190,
          unit: '6 банок',
          imageAsset: 'assets/demo/p12.jpg',
        ),
        Product(
          id: 13,
          categoryId: 3,
          name: 'Сыр бейяз пейнир в рассоле',
          description:
              'Белый сыр из овечьего молока — основа турецкого завтрака. '
              'Солёный, плотный, хорошо крошится в салат. '
              'В вакуумной упаковке, доедет и до дома.',
          price: 1120,
          unit: '500 г',
          imageAsset: 'assets/demo/p13.jpg',
        ),
        Product(
          id: 14,
          categoryId: 3,
          name: 'Оливки Гемлик чёрные вяленые',
          description:
              'Сорт Гемлик — мелкие, мясистые, с насыщенным вкусом без горечи. '
              'Вялены на солнце и залиты оливковым маслом. '
              'Лучшая закуска к белому сыру и хлебу.',
          price: 780,
          unit: '400 г',
          imageAsset: 'assets/demo/p14.jpg',
        ),
        Product(
          id: 15,
          categoryId: 3,
          name: 'Сосновый мёд «чам балы»',
          description:
              'Редкий тёмный мёд из сосновой пади с гор Тавра, почти не кристаллизуется. '
              'Менее сладкий, чем цветочный, с лёгкой смолистой ноткой. '
              'Собран в горах над Кемером.',
          price: 2890,
          unit: '850 г',
          imageAsset: 'assets/demo/p15.jpg',
        ),

        // ── Напитки ──────────────────────────────────────────────────────
        Product(
          id: 16,
          categoryId: 4,
          name: 'Кофе Kurukahveci Mehmet Efendi',
          description:
              'Самый известный турецкий молотый кофе, помол под джезву. '
              'Обжарка средняя, пенка густая — на неё тут и смотрят. '
              'Вакуумная упаковка, аромат держится до вскрытия.',
          price: 690,
          unit: '250 г',
          imageAsset: 'assets/demo/p16.jpg',
        ),
        Product(
          id: 17,
          categoryId: 4,
          name: 'Гранатовый чай в гранулах',
          description:
              'Растворимый чай с гранатом — заливается кипятком, готов сразу. '
              'Кисло-сладкий, вкусный и горячим, и со льдом. '
              'Тот самый, который наливают в лавках на дегустации.',
          price: 540,
          unit: '300 г',
          imageAsset: 'assets/demo/p17.jpg',
        ),
        Product(
          id: 18,
          categoryId: 4,
          name: 'Чёрный чай Caykur Rize',
          description:
              'Классический турецкий чай из Ризе, выращенный на черноморских склонах. '
              'Заваривается в двухэтажном чайнике, цвет — насыщенный янтарный. '
              'Пачки хватает надолго.',
          price: 620,
          unit: '500 г',
          imageAsset: 'assets/demo/p18.jpg',
        ),
        Product(
          id: 19,
          categoryId: 4,
          name: 'Айран Sutas',
          description:
              'Холодный кисломолочный напиток с солью — местный ответ на жару. '
              'Хорошо идёт с мясом и просто после пляжа. '
              'Привозим охлаждённым, в термосумке.',
          price: 350,
          unit: '1 л',
          imageAsset: 'assets/demo/p19.jpg',
        ),
        Product(
          id: 20,
          categoryId: 4,
          name: 'Гранатовый сок прямого отжима',
          description:
              'Сок из граната без сахара, воды и концентрата — отжим и всё. '
              'Терпкий, густой, тёмно-рубиновый. '
              'Держать в холодильнике и выпить за пару дней.',
          price: 890,
          unit: '1 л',
          imageAsset: 'assets/demo/p20.jpg',
          isAvailable: false,
        ),

        // ── Сладости ─────────────────────────────────────────────────────
        Product(
          id: 21,
          categoryId: 5,
          name: 'Турецкий лукум ассорти',
          description:
              'Шесть вкусов в одной коробке: фисташка, роза, гранат, грецкий орех, '
              'лимон и двойная обжарка. Свежий, мягкий, не липнет к рукам. '
              'Подарок, который увозят из Турции чаще всего.',
          price: 1150,
          unit: '500 г',
          imageAsset: 'assets/demo/p21.jpg',
        ),
        Product(
          id: 22,
          categoryId: 5,
          name: 'Пахлава фисташковая',
          description:
              'Сорок слоёв теста, антепская фисташка и сироп — печётся утром того же дня. '
              'Не приторная: сиропа ровно столько, чтобы держать форму. '
              'В плотной коробке, довезёте целой.',
          price: 2450,
          oldPrice: 2990,
          unit: '1 кг',
          imageAsset: 'assets/demo/p22.jpg',
        ),
        Product(
          id: 23,
          categoryId: 5,
          name: 'Халва тахинная с фисташками',
          description:
              'Кунжутная халва с целыми фисташками, рассыпчатая, без пальмового масла. '
              'Сладость плотная — хватает пары кусочков к кофе. '
              'В герметичной упаковке.',
          price: 980,
          unit: '400 г',
          imageAsset: 'assets/demo/p23.jpg',
        ),
        Product(
          id: 24,
          categoryId: 5,
          name: 'Пишмание, турецкая сахарная вата',
          description:
              'Тонкие нити из вытянутого теста с сахаром, тают во рту. '
              'Делаются вручную и до сих пор считаются праздничной сладостью. '
              'Дети сметают коробку за вечер.',
          price: 760,
          unit: '350 г',
          imageAsset: 'assets/demo/p24.jpg',
        ),
        Product(
          id: 25,
          categoryId: 5,
          name: 'Шоколадные драже с фундуком',
          description:
              'Цельный турецкий фундук в молочном шоколаде и хрустящей глазури. '
              'Фундук из Гиресуна — того самого региона, что кормит всю Европу. '
              'В банке с крышкой, удобно брать на пляж.',
          price: 1340,
          unit: '500 г',
          imageAsset: 'assets/demo/p25.jpg',
        ),

        // ── Пляж ─────────────────────────────────────────────────────────
        Product(
          id: 26,
          categoryId: 6,
          name: 'Пляжное полотенце пештемаль',
          description:
              'Тонкое хлопковое полотенце-пештемаль 90 на 170 см. '
              'Сохнет за полчаса, песок стряхивается целиком, '
              'в сумке занимает вдвое меньше махрового.',
          price: 1290,
          unit: 'шт',
          imageAsset: 'assets/demo/p26.jpg',
        ),
        Product(
          id: 27,
          categoryId: 6,
          name: 'Солнцезащитный крем SPF 50+',
          description:
              'Водостойкий крем с широким UVA/UVB-фильтром для лица и тела. '
              'Не оставляет белого следа и не течёт в глаза. '
              'В Кемере в июле без него на пляж лучше не выходить.',
          price: 1680,
          unit: '200 мл',
          imageAsset: 'assets/demo/p27.jpg',
        ),
        Product(
          id: 28,
          categoryId: 6,
          name: 'Маска и трубка для снорклинга',
          description:
              'Маска с закалённым стеклом и трубка с клапаном слива, взрослый размер. '
              'Силиконовый обтюратор не давит и не пропускает воду. '
              'У скал в Кемере вода прозрачная, смотреть есть на что.',
          price: 2790,
          oldPrice: 3490,
          unit: 'набор',
          imageAsset: 'assets/demo/p28.jpg',
        ),
        Product(
          id: 29,
          categoryId: 6,
          name: 'Пляжная сумка из соломы',
          description:
              'Плетёная сумка с подкладкой и внутренним карманом на молнии. '
              'Влезает полотенце, книга, вода и крем. '
              'Держит форму и не колется изнутри.',
          price: 1450,
          unit: 'шт',
          imageAsset: 'assets/demo/p29.jpg',
        ),
        Product(
          id: 30,
          categoryId: 6,
          name: 'Надувной матрас для плавания',
          description:
              'Матрас 180 на 70 см из плотного винила с подголовником и ручками. '
              'Выдерживает взрослого, надувается насосом за пару минут. '
              'В сдутом виде помещается в чемодан.',
          price: 4500,
          unit: 'шт',
          imageAsset: 'assets/demo/p30.jpg',
        ),
      ];

  /// Промокоды демо. `EXPIRED` заведён НАРОЧНО просроченным: экран чекаута
  /// обязан показывать и неудачу тоже, а проверить её иначе нечем.
  static List<DemoPromo> promos() => const [
        DemoPromo(code: 'KEMER10', percent: 10),
        DemoPromo(code: 'TURTUK500', amount: 500),
        DemoPromo(code: 'SUMMER', percent: 15),
        DemoPromo(code: 'EXPIRED', percent: 20, expired: true),
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

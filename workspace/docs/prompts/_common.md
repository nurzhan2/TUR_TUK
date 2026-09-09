# TUR TUK — общий контекст для сессий 2–5

**Читай этот файл первым.** Дальше открывай свой: `s2-catalog.md`,
`s3-cart-checkout.md`, `s4-orders-tracking-chat.md`, `s5-auth-profile-courier.md`.

## Что за проект

Приложение доставки сувениров, косметики и продуктов в отели Кемера (Турция)
для русскоязычных туристов. Заказчица — Анастасия, 9 сентября написала
«Покажите что уже готово». Мы собираем **демо**: приложение должно
запускаться без бэкенда, на моках, и выглядеть законченным.

**Приоритет — визуальная полнота и красота экранов.** Не архитектурная
чистота, не покрытие тестами, не боевые сценарии. Если выбор между «сделать
правильно» и «сделать так, чтобы на экране было красиво» — второе.

Корень репозитория: `C:\dev\TUR_TUK`. Код: `workspace/client_app`,
`workspace/courier_app`. Бэкенд (FastAPI, готов) — `workspace/backend`,
только для чтения схем.

## Параллельная работа

Над репозиторием одновременно работают 4 сессии. **Правь только файлы из
списка владения в своём промте.** Всё остальное — чтение.

Не трогай никогда: `pubspec.yaml`, `lib/main.dart`, `lib/app.dart`,
`lib/core/**`, `lib/models/**`, `lib/data/**`, `lib/controllers/**`,
`lib/l10n/**`, `assets/**`, `workspace/backend/**`.
Не делай `git commit` в чужие ветки, `git checkout`, `git stash`, `git merge`.

Работай в своей ветке (`feature/s2-catalog` и т.д.), в конце — PR в `main`.

**Чужие ошибки анализатора игнорируй.** На старте в дереве могут быть
ошибки в файлах других сессий. Не правь их, не «чини» контракт под них.
Фильтруй вывод `flutter analyze` по своим путям.

## Слой данных — уже готов, менять нельзя

Всё уже написано и проверено запуском. Ты только используешь.

### Демо-режим

```dart
// lib/core/demo/demo_mode.dart
const bool kDemoMode = bool.fromEnvironment('DEMO', defaultValue: true);
```

Развилка «демо или бэкенд» стоит внутри `Di`. Выше уровня `Di` о демо-режиме
не знает никто — **не пиши `if (kDemoMode)` в экранах**.

### Модели (`lib/models/`)

```dart
Product   { int id; String name; String description; double price; double? oldPrice;
            int? categoryId; String imageAsset; String unit; bool isAvailable;
            bool get hasDiscount; int get discountPercent }
Category  { int id; String name; int? parentId; List<Category> children; IconData icon }
CartItem  { int id; Product product; int quantity; double get lineTotal }
Cart      { List<CartItem> items; double total; int get count; bool get isEmpty }
OrderStatus { created, accepted, assembling, delivering, delivered, cancelled;
              bool get isFinal; int get step /* 0..4, cancelled = -1 */ }
OrderItem { int productId; String name; double price; int quantity;
            String imageAsset; double get lineTotal }
Order     { int id; OrderStatus status; double total; double discount; double deliveryFee;
            String hotelName; String roomNumber; DateTime createdAt; List<OrderItem> items;
            String? courierName; String? promoCode; String? deliveryPhotoAsset;
            double hotelLat, hotelLng, courierLat, courierLng; double get subtotal }
ChatMessage { int id; String text; bool isBot; bool isMine; DateTime createdAt }
PromoResult { bool valid; String code; double discount; double totalAfterDiscount; String? error }
UserProfile { String name; String phone; String hotelName; String roomNumber; DateTime? dob }
```

`imageAsset` — путь вида `assets/demo/p07.jpg`, показывать через `Image.asset`.

### Контроллеры (`lib/controllers/`) — через `provider`

Все подняты в `MultiProvider` на весь запуск. `context.watch<X>()` для чтения
в `build`, `context.read<X>()` для вызова методов.

У каждого: `ControllerState state` (`initial/loading/loaded/error`,
есть `.isLoading`, `.isError`, `.isLoaded`) и `String? errorMessage`.

```dart
CatalogController
  List<Category> categories; List<Product> products;
  int? selectedCategoryId; String searchQuery;
  Future<void> load();
  Future<void> selectCategory(int? id);   // null = «Все»
  Future<void> search(String query);
  Product? cached(int id);                // товар из уже загруженного списка

CartController
  Cart cart; int get count; double get total; bool get isEmpty;
  Future<void> load();
  Future<void> add(int productId, {int qty = 1});
  Future<void> setQuantity(int itemId, int qty);
  Future<void> remove(int itemId);
  Future<void> clear();
  int quantityOf(int productId);          // сколько этого товара уже в корзине

OrdersController
  List<Order> orders; Order? lastCreated;
  Future<void> load();
  Order? byId(int id);
  Future<Order> create({required String hotelName, required String roomNumber,
                        String? promoCode, String? comment});
  Future<Order> repeat(int id);           // в демо кладёт позиции в КОРЗИНУ
  Stream<Order> track(int id);            // тик раз в 4 с, курьер едет, статус растёт
  void applyTracked(Order order);         // применить состояние из трекинга к списку

ChatController
  List<ChatMessage> messages; bool botTyping;
  Future<void> load(); Future<void> send(String text);

AuthController
  UserProfile? profile; bool get isAuthorized; String? phone;
  Future<void> load();
  Future<void> sendCode(String phone);
  Future<bool> verifyCode(String code);   // ТОЛЬКО код, телефон уже сохранён
  Future<void> register({required String name, required String hotelName,
                         required String roomNumber, DateTime? dob});
  Future<void> logout();

LocaleController
  Locale locale;  void setLocale(Locale value);
```

`verifyCode` возвращает `false` на неверный код — это обычный исход формы,
`state` при этом не становится `error`. Подсвечивай поле, а не показывай
«повторить».

### Промокоды, суммы, отели

- Минимальная сумма заказа: **3000 ₽** (`DemoData.minOrderTotal`)
- Доставка: **300 ₽** (`DemoData.deliveryFee`), бесплатно от 5000 ₽
- Рабочие промокоды в демо: `KEMER10` (−10%), `TURTUK500` (−500 ₽),
  `SUMMER` (−15%), `EXPIRED` (просрочен, показывает ошибку)
- Профиль по умолчанию: Анастасия, +7 999 123-45-67, Rixos Sungate, номер 412
- В каталоге 30 товаров, 6 категорий, у 4 товаров есть `oldPrice`,
  2 товара `isAvailable: false`

## Маршруты (`lib/core/router/app_router.dart`)

```dart
AppRoutes.splash    '/'
AppRoutes.auth      '/auth'
AppRoutes.catalog   '/catalog'
AppRoutes.cart      '/cart'
AppRoutes.checkout  '/checkout'
AppRoutes.orders    '/orders'
AppRoutes.chat      '/chat'
AppRoutes.profile   '/profile'
AppRoutes.productPath(int id)    // '/catalog/product/7'
AppRoutes.orderPath(int id)      // '/orders/1043'
AppRoutes.trackingPath(int id)   // '/tracking/1043'
```

`ProductScreen(productId: int)`, `OrderDetailScreen(orderId: int)`,
`TrackingScreen(orderId: int)` — **сигнатуры фиксированы роутером**,
менять нельзя.

Каталог, корзина, заказы и профиль живут внутри `ShellRoute` с нижней
навигацией. Чекаут, чат и трекинг открываются поверх — `context.push`.
Карточка заказа вложена в `/orders`, поэтому «назад» возвращает в список.

## Тема (`lib/core/theme/app_theme.dart`)

```dart
AppColors.accent      0xFF8B0000   // бордовый, главный
AppColors.accentDark  0xFF6E0000
AppColors.accentSoft  0xFFFBEDED   // фон плашек и активных чипов
AppColors.background  0xFFFFFFFF
AppColors.surface     0xFFF6F6F7
AppColors.border      0xFFEEEEEF
AppColors.textPrimary 0xFF1A1A1A
AppColors.textMuted   0xFF8A8A8E
AppColors.error / .success / .warning

AppSizes.radius 16   .radiusSmall 12   .gap 12   .pagePadding 16
```

Ориентир по стилю — приложение «Самокат»: белый фон, крупные жирные
заголовки, мягкие карточки без теней с бордером, один бордовый акцент.

Цены — **только** через `money(double)` из `lib/core/format.dart`:
`money(1250)` → `1 250 ₽` с неразрывными пробелами. Руками цену не собирай.

## Локализация

`AppLocalizations.of(context)!` — ru / en / tr. 93 ключа уже заведены,
список — в `lib/l10n/app_ru.arb`. **Новые ключи не добавляй**: файл общий,
две сессии одновременно его сломают. Если нужной строки нет — возьми
ближайшую по смыслу или напиши литералом с комментарием `// TODO l10n`.

Никаких русских литералов в UI, кроме контента из демо-данных
(названия товаров, тексты бота — они приходят из моделей).

## Приёмка

`flutter analyze` в этом проекте работает (кириллица из пути убрана).

Обязательно для каждой сессии:

1. `cd workspace/client_app && flutter analyze` → 0 errors и 0 warnings
   **в твоих файлах**
2. `flutter run -d chrome --dart-define=DEMO=true` → пройти свой сценарий
   руками, глазами, в браузере. Не «код выглядит правильно», а «я нажал и
   увидел»
3. Скриншоты своих экранов в `workspace/docs/screens/` (имена — в промте)
4. В отчёте: что проверено живьём, что осталось на доработку

Виджет-тесты пиши, только если остаётся время. Скриншот важнее теста.

# Сессия 4 — Заказы, трекинг на карте, чат

Прочитай сначала `docs/prompts/_common.md` — там контракт, тема, маршруты,
контроллеры. Здесь только твоя часть.

Ветка: `feature/s4-orders-tracking-chat`

## Владение

Правишь только:

```
workspace/client_app/lib/features/orders/**
workspace/client_app/lib/features/tracking/**
workspace/client_app/lib/features/chat/**
```

`orders/order_detail_screen.dart` и `tracking/tracking_screen.dart` сейчас
— заглушки на 15 строк, заведённые ради маршрутов. Переписывай целиком,
сигнатуры конструкторов (`orderId`) не меняй.

## Что показываем

Три экрана, которые доказывают, что приложение живое: заказ едет, курьер
двигается по карте, бот отвечает. Демо-данные уже содержат 4 заказа в
разных статусах, включая доставленный с фото коробки.

## 1. `orders/orders_screen.dart`

`AppBar` с `ordersTitle`, `RefreshIndicator`, загрузка в `initState`.

**Карточка заказа**:
- строка: `orderNumber(order.id)` слева `titleMedium`, справа
  статус-пилюля
- статус-пилюля: скруглённый контейнер, цвет по статусу —
  `created` серый `AppColors.textMuted`, `accepted` синий `0xFF2F6FED`,
  `assembling` оранжевый `AppColors.warning`, `delivering` бордовый
  `AppColors.accent`, `delivered` зелёный `AppColors.success`,
  `cancelled` красный `AppColors.error`. Фон — цвет с прозрачностью 0.12,
  текст — сам цвет, 12/`w600`. Подписи из l10n: `orderStatusCreated` и т.д.
- дата и время: `DateFormat('d MMMM, HH:mm', 'ru')` из `intl`
- `orderDeliveryTo`: отель и комната
- стопка миниатюр: до 4 фото позиций 40×40 круглыми, внахлёст со
  смещением −12 по горизонтали, белая обводка 2; если позиций больше —
  пятый кружок «+N» на `AppColors.surface`
- сумма `money(order.total)` жирным
- кнопка: у незавершённых (`!status.isFinal`) — `orderTrack` →
  `context.push(AppRoutes.trackingPath(id))`; у `delivered` — `orderRepeat`
- `orderRepeat` вызывает `OrdersController.repeat(id)`, показывает
  `SnackBar` «Товары добавлены в корзину» с действием «В корзину»
- тап по карточке → `context.push(AppRoutes.orderPath(order.id))`

**Состояния**: `loading` — 3 скелетона-карточки с пульсацией;
`error` — иконка + `errorMessage` + `retry`; пусто — иконка,
`ordersEmpty`, кнопка в каталог.

## 2. `orders/order_detail_screen.dart`

`OrderDetailScreen({required int orderId})`. Заказ берётся
`context.watch<OrdersController>().byId(orderId)`; если `null` — вызвать
`load()` один раз и показать индикатор, затем «заказ не найден» без
падения.

**Таймлайн статусов** — главный элемент экрана. Вертикальный список из
5 шагов: Создан, Принят, Собирается, Доставляется, Доставлен
(подписи из l10n). Слева колонка кружков 24×24, соединённых линией 2px:
- пройденные (`step < order.status.step`): бордовая заливка, белая галочка
- текущий (`step == order.status.step`): бордовый кружок с пульсирующим
  ореолом — `AnimationController` с `repeat(reverse: true)`, меняющий
  прозрачность внешнего круга. Контроллер обязательно `dispose`.
- будущие: серый контур `AppColors.border`, линия серая
Справа — подпись шага, у пройденных ещё и время серым.
Отменённый заказ (`step == -1`) — таймлайн не рисуем, вместо него
красная плашка «Заказ отменён».

**Блок курьера** (если `courierName != null`): круглый аватар 48 с
первой буквой имени на `AppColors.accentSoft` бордовым, имя,
`orderCourier` подписью. Справа две круглые кнопки: чат
(`Icons.chat_bubble_outline` → `context.push(AppRoutes.chat)`) и звонок
(`Icons.call_outlined` → `SnackBar` «Звонок курьеру», это демо).

**Адрес**: карточка с иконкой, отель и номер комнаты.

**Состав заказа**: список позиций — миниатюра 44, название,
«N × money(price)», справа `money(lineTotal)`.

**Итог**: `checkoutSubtotal` (`order.subtotal`), `checkoutDiscount`
(если есть, бордовым с минусом, рядом серым код промокода),
`checkoutDelivery`, крупно `checkoutTotal` (`order.total`).

**Фото доставки** (только при `deliveryPhotoAsset != null`): секция
`orderDeliveryPhoto`, `Image.asset` на всю ширину, радиус 16, подпись
серым «Коробка передана на рецепцию». Это сильный элемент показа —
сделай крупно.

**Кнопка снизу** у незавершённых: `orderTrack`.

## 3. `tracking/tracking_screen.dart`

`TrackingScreen({required int orderId})`, `StatefulWidget`.

В `initState` подписаться на `context.read<OrdersController>().track(orderId)`,
на каждое событие обновлять локальный `Order` и звать `applyTracked(order)`,
чтобы список заказов не отстал. **Подписку отменять в `dispose`** — иначе
после выхода с экрана `setState` полетит в мёртвый виджет.

**Карта** — `flutter_map` (пакет уже в зависимостях):
- `TileLayer` с `urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'`
  и обязательным `userAgentPackageName: 'ru.turtuk.client'`
- центр — середина между курьером и отелем, зум ~13, карта на весь экран
- `PolylineLayer`: линия от курьера к отелю, `AppColors.accent`,
  толщина 4, прозрачность 0.7
- `MarkerLayer`: курьер — бордовый круг 44 с белой иконкой
  `Icons.delivery_dining`, тень; отель — белый круг 44 с бордовой
  `Icons.location_on` и бордером
- камера плавно следует за курьером при каждом тике (`MapController.move`)
- **если тайлы не грузятся** (демо могут смотреть без интернета):
  `errorTileCallback`, под тайлами — фон `AppColors.surface`. Маркеры и
  линия видны всё равно, экран не падает и не становится пустым белым

**Карточка поверх карты** снизу, белая, радиус 24 сверху, тень:
- статус-пилюля (тот же виджет, что в списке заказов — вынеси его в
  `orders/widgets/status_pill.dart` и переиспользуй)
- `trackingCourierOnWay` крупно, при `delivered` — `trackingArrived`
- `trackingEta(minutes)` — считай грубо: `(1 - прогресс) * 20` минут,
  прогресс — по расстоянию курьера от старта к отелю
- имя курьера с аватаром
- две кнопки: чат и звонок

Сверху слева — круглая кнопка «назад» поверх карты.

## 4. `chat/chat_screen.dart`

`AppBar` с `chatTitle` и подзаголовком «Отвечаем за пару минут».
Загрузка истории в `initState`.

**Лента сообщений**: `ListView` с `reverse: false` и автоскроллом вниз
через `ScrollController` после каждого нового сообщения.

- моё (`isMine`): справа, фон `AppColors.accent`, белый текст, радиус 16
  со срезанным правым нижним углом (4)
- бот (`isBot`): слева, фон `AppColors.surface`, тёмный текст, над пузырём
  мелкая метка `chatBotLabel` бордовым
- оператор (ни то, ни другое): слева, фон `AppColors.accentSoft`, метка
  `chatOperatorLabel`
- под каждым пузырём время `HH:mm` серым 11
- максимальная ширина пузыря — 78% экрана

**Быстрые вопросы**: если сообщений мало, под лентой ряд чипов, тап
отправляет текст вопроса. Формулировки подобраны под ключевые слова бота,
не меняй их:
- «Минимальная сумма заказа?»
- «Как оплатить?»
- «Куда привезут заказ?»
- «Есть промокод?»

**Индикатор печати**: при `controller.botTyping` — пузырь слева с тремя
точками, которые по очереди прыгают (`AnimationController`, 1200 мс,
`repeat`). Обязательно `dispose`.

**Поле ввода** снизу: `TextField` с `chatHint`, круглая бордовая кнопка
отправки справа, `SafeArea`. Пустое сообщение не отправляется.

## Приёмка

1. `cd workspace/client_app && flutter analyze` → в `features/orders/**`,
   `features/tracking/**`, `features/chat/**` ноль errors и ноль warnings
2. `flutter run -d chrome --dart-define=DEMO=true` и пройти руками:
   - в списке 4 заказа, у каждого свой цвет статуса и стопка миниатюр
   - у доставленного #1042 кнопка «Повторить» кладёт товары в корзину
     (проверь бейдж внизу)
   - карточка заказа: таймлайн подсвечен по статусу, текущий шаг пульсирует
   - у #1042 видно фото коробки
   - трекинг #1043: карта грузится, курьер и отель на местах, линия между
     ними; **подожди 12 секунд** — курьер сдвинулся минимум дважды
   - дождись `delivered` (около минуты) — карточка снизу сменила текст
   - вернулся в список — статус там обновился
   - чат: тап по чипу «Как оплатить?» → появились три точки → ответ бота
     про карту и СБП
   - любой свой текст → ответ-заглушка бота
3. Скриншоты в `workspace/docs/screens/`: `orders.png`,
   `order_detail.png`, `order_delivered.png` (с фото коробки),
   `tracking.png`, `chat.png`
4. В отчёте отдельно: загрузились ли тайлы карты и как экран выглядит
   без интернета

# Сессия 3 — Корзина и оформление заказа

Прочитай сначала `docs/prompts/_common.md` — там контракт, тема, маршруты,
контроллеры. Здесь только твоя часть.

Ветка: `feature/s3-cart-checkout`

## Владение

Правишь только:

```
workspace/client_app/lib/features/cart/**
workspace/client_app/lib/features/checkout/**
```

Оба существующих файла — заглушки на 20 строк, переписывай целиком.

## Что показываем

Это воронка покупки целиком: корзина → адрес доставки → промокод →
оплата → «заказ оформлен». Заказчица пройдёт её на показе от начала до
конца, и на каждом шаге цифры должны сходиться.

## 1. `cart/cart_screen.dart`

`AppBar` с `cartTitle` и иконкой очистки справа (`Icons.delete_outline`)
— по нажатию `AlertDialog` с подтверждением, затем `clear()`.

**Список позиций** — каждая строка:
- фото 76×76, `ClipRRect(radius 12)`, `Image.asset` с `errorBuilder`
- название 2 строки, `unit` серым
- `money(item.product.price)` жирным, справа от него `money(item.lineTotal)`
  если количество больше 1
- степпер «− N +» справа: `setQuantity(item.id, N±1)`, а при N=1 и минусе
  — `remove(item.id)`
- `Dismissible` со свайпом влево: красный фон с иконкой корзины,
  удаление + `SnackBar` «Товар удалён» с действием «Отменить»
  (вернуть через `add(productId, qty: N)`)

**Пустая корзина**: иконка `Icons.shopping_cart_outlined` 72 серым,
`cartEmpty`, кнопка «Перейти в каталог» → `context.go(AppRoutes.catalog)`.

**Блок «Итого»** карточкой внизу списка:
- `checkoutSubtotal` — `money(cart.total)`
- `checkoutDelivery` — `money(300)`, либо зелёным «Бесплатно» при сумме
  от 5000 ₽
- `cartTotal` — сумма с доставкой, крупно и жирно

**Минимальная сумма**: если `cart.total < 3000` — плашка
`AppColors.accentSoft` с иконкой, текстом `cartMinOrder` (передай
недостающую сумму) и `LinearProgressIndicator` заполненности
`cart.total / 3000` бордовым. Кнопка оформления при этом `null`-обработчик,
то есть визуально disabled.

**Нижняя закреплённая панель**: кнопка `cartCheckout` на всю ширину с
суммой к оплате внутри, `SafeArea`, белый фон с бордером сверху.

Загрузка корзины — `load()` в `initState` через `addPostFrameCallback`.

## 2. `checkout/checkout_screen.dart`

`StatefulWidget`, одна прокручиваемая страница, секции — карточки с
бордером `AppColors.border`, радиус 16, между ними 12.

### Секция «Доставка»

- Выпадающий список отелей. Заведи свой файл
  `checkout/kemer_hotels.dart` со списком из 8 названий: Rixos Sungate,
  Club Med Palmiye, Maxx Royal Kemer, Amara Prestige, Crystal Sunset
  Luxury, Orange County Kemer, Akra Kemer, Sherwood Exclusive Kemer.
  Значение по умолчанию — `AuthController.profile?.hotelName`, если оно
  есть в списке, иначе первый элемент.
- Поле «номер комнаты» (`checkoutRoom`), по умолчанию
  `profile?.roomNumber`, клавиатура числовая
- Поле комментария курьеру (`checkoutComment`), 2 строки, необязательное
- Плашка-подсказка `AppColors.surface` с иконкой
  `Icons.info_outline`: «Курьер оставит заказ на рецепции — заберёте его
  по номеру заказа или последним 4 цифрам телефона»

### Секция «Промокод»

Поле `checkoutPromo` + кнопка `checkoutPromoApply` в строку.
По нажатию — `Di.promo.validate(code, cart.total)` напрямую (контроллера
для промокодов нет, это нормально), пока идёт — маленький индикатор в
кнопке.

- Успех (`result.valid`): зелёная плашка с галочкой,
  `checkoutPromoApplied`, `−money(result.discount)`, крестик «убрать»,
  поле блокируется. Скидка сразу пересчитывает итог.
- Неудача: красный текст под полем — `result.error`, если он есть, иначе
  `checkoutPromoInvalid`. Поле подсвечивается красным.

Проверь на `EXPIRED` — он для того и заведён.

### Секция «Оплата»

Два `RadioListTile`: `checkoutPaymentCard` с иконкой
`Icons.credit_card` и `checkoutPaymentSbp` с иконкой
`Icons.qr_code_2`. По умолчанию карта. **Наличных нет вообще** — клиент
их отдельно исключил из ТЗ.

### Секция «Ваш заказ»

Первые 3 позиции миниатюрами 44×44 с названием и количеством, дальше
серым «ещё N товаров». Разворачивается по тапу.

### Итог

Строки: `checkoutSubtotal`, `checkoutDiscount` (бордовым со знаком минус,
показывать только если скидка есть), `checkoutDelivery`,
разделитель, `checkoutTotal` крупно и жирно.

### Нижняя панель

Кнопка `checkoutPay` с суммой. По нажатию:
1. Индикатор внутри кнопки, `Future.delayed(1500)` — имитация оплаты.
   Никаких редиректов в ЮKassa, это демо.
2. `OrdersController.create(hotelName:, roomNumber:, promoCode:, comment:)`
3. `CartController.clear()`
4. Переход на экран успеха

Если сумма меньше 3000 — не пускать, показать `checkoutMinOrderError`.

## 3. `checkout/order_success_screen.dart`

Новый файл, отдельный маршрут не нужен — открывай через
`Navigator.of(context, rootNavigator: true).pushReplacement`, чтобы
«назад» не возвращал на чекаут с уже очищенной корзиной.

- Белый фон, по центру галочка в бордовом круге 96×96 с анимацией
  появления (`ScaleTransition`, `Curves.elasticOut`, 600 мс). Lottie не
  подключён, не добавляй.
- `checkoutSuccess` с номером заказа из `OrdersController.lastCreated`
- `checkoutSuccessSub`: доставим на рецепцию такого-то отеля за 40–60 минут
- Кнопка `orderTrack` → `context.go(AppRoutes.trackingPath(order.id))`
- Текстовая кнопка «В каталог» → `context.go(AppRoutes.catalog)`

Экран трекинга пишет другая сессия. Если на момент твоей проверки он ещё
заглушка — это нормально, проверь только что переход происходит и id
подставился.

## Приёмка

1. `cd workspace/client_app && flutter analyze` → в `features/cart/**` и
   `features/checkout/**` ноль errors и ноль warnings
2. `flutter run -d chrome --dart-define=DEMO=true` и пройти руками:
   - добавить в каталоге товаров меньше чем на 3000 ₽ → в корзине плашка
     минималки, прогресс-бар, кнопка не нажимается
   - добрать до 3000+ → плашка ушла, кнопка активна
   - степпер меняет количество, сумма пересчитывается
   - свайп удаляет позицию, «Отменить» возвращает
   - на чекауте отель и комната подставились из профиля
   - `KEMER10` даёт зелёную плашку и уменьшает итог ровно на 10%
   - `EXPIRED` даёт красную ошибку и итог не меняет
   - оплата → экран успеха с номером → заказ виден в списке заказов
   - корзина после оформления пустая
3. Скриншоты в `workspace/docs/screens/`: `cart.png`,
   `cart_min_order.png` (с плашкой минималки), `checkout.png`,
   `checkout_promo.png` (с применённым промокодом), `success.png`
4. В отчёте — сходятся ли цифры на каждом шаге

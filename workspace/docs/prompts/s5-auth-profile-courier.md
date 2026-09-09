# Сессия 5 — Авторизация, профиль, курьерское приложение

Прочитай сначала `docs/prompts/_common.md` — там контракт, тема, маршруты,
контроллеры. Здесь только твоя часть.

Ветка: `feature/s5-auth-profile-courier`

## Владение

Правишь только:

```
workspace/client_app/lib/features/auth/**
workspace/client_app/lib/features/splash/**
workspace/client_app/lib/features/profile/**
workspace/courier_app/**            (весь целиком, включая pubspec и l10n)
```

В `client_app` ограничения из `_common.md` действуют полностью.
В `courier_app` ты единственный хозяин — там можно всё, включая
`pubspec.yaml` и `.arb`-файлы.

## Часть А — client_app

### 1. `splash/splash_screen.dart`

Белый фон, по центру «TUR TUK» бордовым `w800` размером 40 и подпись
серым «Доставка в отели Кемера». Появление — `FadeTransition` 800 мс.

Через 1200 мс: вызвать `AuthController.load()`, затем
`context.go(AppRoutes.catalog)`.

**В демо на экран входа не уводить никогда.** `DemoAuthRepository.currentUser()`
возвращает профиль Анастасии, так что `isAuthorized` истинно — но даже
если бы не возвращал, со splash идём в каталог. Упереться в форму логина
посреди показа заказчице — худший сценарий демонстрации. Вход живёт
отдельным экраном и открывается из профиля.

### 2. `auth/auth_screen.dart`

Два шага в одном экране — `PageView` с `physics: NeverScrollableScrollPhysics`,
переключение только кнопками.

**Шаг 1 — телефон:**
- `authTitle` крупно, `authSubtitle` серым
- поле телефона с маской `+7 (___) ___-__-__`. Пакета маски нет —
  сделай `TextInputFormatter` сам, это 30 строк
- кнопка `authGetCode` — активна только при 11 цифрах, вызывает
  `AuthController.sendCode(phone)` и листает на шаг 2
- мелким серым внизу: согласие с условиями

**Шаг 2 — код:**
- заголовок с телефоном из `AuthController.phone` и кнопкой «изменить»
  (возврат на шаг 1)
- 4 отдельных квадратных поля 56×56 для цифр, `AppColors.surface`,
  автопереход фокуса вперёд при вводе и назад при `Backspace`,
  активное поле — бордовый бордер
- когда введены 4 цифры — автоматически `verifyCode(code)`
- `false` в ответе: поля краснеют, под ними `authInvalidCode`,
  ввод очищается. **`state` при этом не `error`** — не показывай
  «повторить»
- таймер `authResend(seconds)` на 45 секунд, после — активная кнопка
  повторной отправки. Таймер отменять в `dispose`
- в демо проходят любые 4 цифры

После успеха: если `profile == null` — на экран регистрации, иначе
`context.go(AppRoutes.catalog)`.

### 3. `auth/register_screen.dart`

Новый файл, маршрута не заводи — открывай через `Navigator.push`.

- `authRegisterTitle` крупно
- поле `authName`
- поле `authDob` — `showDatePicker`, необязательное, формат `d MMMM yyyy`
- выпадающий список отелей `authHotel`. Заведи свой файл
  `auth/kemer_hotels.dart` с теми же 8 отелями: Rixos Sungate, Club Med
  Palmiye, Maxx Royal Kemer, Amara Prestige, Crystal Sunset Luxury,
  Orange County Kemer, Akra Kemer, Sherwood Exclusive Kemer.
  Свой файл, а не общий с чекаутом — сессия 3 пишет свой параллельно,
  дублирование восьми строк дешевле связывания двух веток.
- поле `authRoom`, числовая клавиатура
- плашка-подсказка: «Отель нужен, чтобы курьер знал, куда везти заказ»
- кнопка `authContinue` → `AuthController.register(...)` →
  `context.go(AppRoutes.catalog)`

### 4. `profile/profile_screen.dart`

- Шапка: круглый аватар 72 на `AppColors.accentSoft` с первой буквой
  имени бордовым `w700`, справа имя `titleLarge` и телефон серым
- Карточка «Мой отель»: иконка, `profileHotel` + название,
  `profileRoom` + номер, справа кнопка `profileEdit` → `showModalBottomSheet`
  с полями отеля и комнаты, сохранение через `AuthController.register(...)`
  (тот же метод обновляет профиль)
- **Переключатель языка** — важный пункт показа. Три сегмента
  `profileRussian` / `profileEnglish` / `profileTurkish` в одном
  контейнере `AppColors.surface`, активный — белая плашка с тенью.
  Тап → `LocaleController.setLocale(Locale('ru'|'en'|'tr'))`.
  Интерфейс обязан смениться мгновенно, без перезапуска.
- Список пунктов `ListTile`: `profileMyOrders` → `/orders`,
  `profileSupport` → `/chat`, «О приложении» → диалог, `profileLogout`
  бордовым → `logout()` + переход на `/auth`
- Внизу серым мелким: «TUR TUK · версия 1.0.0»

Если `profile == null` — вместо шапки кнопка «Войти» → `/auth`.

## Часть Б — courier_app

Сейчас там есть: `ApiClient`, `AuthController`/`AuthRepository`, список
заказов с `OrdersController`, тема и три `.arb`. Работает только против
живого бэкенда.

### 5. Демо-режим

Повтори подход клиентского приложения (посмотри
`client_app/lib/core/demo/` и `lib/core/di.dart` как образец, копировать
файлы не обязательно):

- `lib/core/demo/demo_mode.dart` — тот же `kDemoMode`
- `lib/core/demo/demo_data.dart` — 5 заказов: два `created` (новые,
  не назначены), один `assembling`, один `delivering`, один `delivered`.
  Позиции, отели и суммы — правдоподобные, отели из списка Кемера.
- `DemoOrdersRepository` и `DemoAuthRepository`: вход по любому телефону
  и любому 4-значному коду, смена статуса меняет заказ в памяти
- развилка в одном месте, как `Di` в клиентском

### 6. Экраны

**Список заказов** — переписать существующий: три секции с заголовками
«Новые» / «В работе» / «Выполненные». Карточка: номер, статус-пилюля,
отель и комната, количество позиций, сумма, время. Тап → детали.

**Детали заказа** (новый файл):
- состав заказа списком
- блок клиента: имя, телефон (кнопка звонка), отель, номер комнаты
- у `created`: две кнопки — «Принять» (зелёная) и «Отклонить» (контурная)
- у принятых: одна крупная кнопка следующего шага —
  «Начать сборку» → «Выехал» → «Доставлен»
- кнопка «Маршрут» → экран карты

**Подтверждение доставки**: при переводе в «Доставлен» — экран с кнопкой
«Сфотографировать коробку». В демо по нажатию показывается
`assets/demo/box01.jpg` как только что сделанный снимок, кнопка
«Подтвердить доставку» завершает заказ.
Скопируй `box01.jpg` из `client_app/assets/demo/` в
`courier_app/assets/demo/` и пропиши ассеты в `courier_app/pubspec.yaml`.

**Маршрут**: `flutter_map` с OSM-тайлами (`userAgentPackageName`
обязателен), маркеры отеля и курьера, линия между ними. Кнопка «Открыть
в навигаторе» через `url_launcher`, схема `geo:lat,lng`. Добавь
`flutter_map`, `latlong2`, `url_launcher` в `courier_app/pubspec.yaml`.

### 7. Тема и локализация курьерского

- Бордовый привести к `0xFF8B0000` (сейчас `0xFF7A1F2B` — расхождение с
  клиентским). Скопируй палитру и `AppSizes` из
  `client_app/lib/core/theme/app_theme.dart`, чтобы два приложения
  выглядели одной системой.
- Убери `unused_import` в `courier_app/lib/core/router/app_router.dart`
  и почини 8 `info` от линтера (`prefer_initializing_formals`,
  `unnecessary_underscores`) — они все в твоих файлах
- Заполни `app_ru.arb`, `app_en.arb`, `app_tr.arb` всеми новыми строками,
  прогони `flutter gen-l10n`

## Приёмка

1. `cd workspace/client_app && flutter analyze` → в `features/auth/**`,
   `features/splash/**`, `features/profile/**` ноль errors и ноль warnings
2. `cd workspace/courier_app && flutter pub get && flutter gen-l10n &&
   flutter analyze` → **ноль issues вообще**, включая info
3. `flutter run -d chrome --dart-define=DEMO=true` для клиентского,
   пройти руками:
   - splash уводит в каталог, не в логин
   - с экрана входа: телефон с маской, любые 4 цифры пускают дальше
   - неверное поведение проверь тоже: ввод 3 цифр не отправляет форму
   - профиль показывает Анастасию и отель
   - переключение на Türkçe меняет подписи вкладок, заголовки каталога,
     корзины и профиля мгновенно; обратно на русский — тоже
   - «Изменить» меняет отель, и на чекауте подставляется новый
4. То же для курьерского: вход → список тремя секциями → принять заказ →
   провести до «Доставлен» с фото коробки → маршрут на карте
5. Скриншоты в `workspace/docs/screens/`: `auth_phone.png`,
   `auth_code.png`, `profile.png`, `profile_tr.png`,
   `courier_orders.png`, `courier_detail.png`, `courier_photo.png`
6. В отчёте: какие экраны клиентского не перевелись при смене языка
   (их пишут другие сессии — просто перечисли, не чини)

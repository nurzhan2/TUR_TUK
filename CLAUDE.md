# TUR TUK — правила работы в этом репозитории

Приложение доставки в отели Кемера. Сейчас собираем **демо для показа
заказчице**: приложение должно запускаться без бэкенда, на моках, и
выглядеть законченным. Приоритет — визуальная полнота экранов.

## Структура

- `workspace/client_app` — Flutter, приложение клиента
- `workspace/courier_app` — Flutter, приложение курьера
- `workspace/backend` — FastAPI, готов, **только для чтения**
- `workspace/docs/prompts/` — задания сессий, начинать с `_common.md`
- `workspace/docs/screens/` — скриншоты для заказчицы

## Параллельные сессии

Над репозиторием работают несколько сессий одновременно, каждая в своей
ветке. **Правь только файлы из списка владения в своём задании**
(`workspace/docs/prompts/sN-*.md`). Всё остальное — чтение.

Не трогай ни при каких условиях:
`pubspec.yaml`, `lib/main.dart`, `lib/app.dart`, `lib/core/**`,
`lib/models/**`, `lib/data/**`, `lib/controllers/**`, `lib/l10n/**`,
`assets/**`, `web/**`, `workspace/backend/**`.

Исключение: сессия S5 владеет всем `workspace/courier_app/**` целиком.

Ошибки анализатора в чужих файлах — не твои. Не чини их, не подгоняй
контракт под них. Фильтруй вывод по своим путям.

## Команды

```bash
cd workspace/client_app
flutter analyze                                      # должно быть 0 errors в твоих файлах
flutter build web --release --dart-define=DEMO=true  # должно проходить
```

Демо-режим включён по умолчанию (`kDemoMode`, `bool.fromEnvironment('DEMO')`).
Бэкенд для работы приложения поднимать не нужно.

В облачной сессии браузера нет — `flutter run -d chrome` и скриншоты
недоступны. Приёмка там: `flutter analyze` + `flutter build web`.
В PR отдельно перечисли, что требует живой визуальной проверки локально.

## Что нельзя менять

- Контракт слоя данных: модели, репозитории, контроллеры, `Di` — они
  написаны и проверены, сигнатуры зафиксированы в `docs/prompts/_common.md`
- Сигнатуры экранов из роутера: `ProductScreen(productId: int)`,
  `OrderDetailScreen(orderId: int)`, `TrackingScreen(orderId: int)`
- Файлы локализации `lib/l10n/*.arb` — 93 ключа уже заведены, новые не
  добавлять (общий файл, две сессии его сломают). Нет нужной строки —
  литерал с `// TODO l10n`
- Палитра и размеры из `lib/core/theme/app_theme.dart`

## Стиль кода

- Цены только через `money(double)` из `lib/core/format.dart`
- Цвета только из `AppColors`, размеры из `AppSizes`
- Никаких русских литералов в UI, кроме контента из демо-данных
- `AnimationController`, `Timer`, `StreamSubscription`, `ScrollController` —
  обязательно освобождать в `dispose`
- Комментарии по-русски, объясняют «почему», а не «что»

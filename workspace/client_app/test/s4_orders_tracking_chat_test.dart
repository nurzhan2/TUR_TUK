// Сценарий приёмки сессии S4: заказы, трекинг, чат.
//
// Написан вместо ручного прохода в Chrome: в облачной сессии браузера нет,
// а «курьер доехал за минуту» и «бот ответил» проверять чем-то надо. Тест
// гоняет те же шаги, что и приёмка из промта, по настоящим демо-данным.

import 'package:client_app/app.dart';
import 'package:client_app/features/chat/chat_screen.dart';
import 'package:client_app/core/demo/demo_state.dart';
import 'package:client_app/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _boot(WidgetTester tester, String location) async {
  // Высокое «окно», чтобы список из четырёх заказов и длинная карточка
  // помещались целиком: ListView строит только видимое.
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const ClientApp());
  await tester.pump();
  appRouter.go(location);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() => DemoState.instance.reset());

  testWidgets('orders list shows 4 demo orders with statuses', (tester) async {
    await _boot(tester, '/orders');

    expect(find.text('Заказ №1045'), findsOneWidget);
    expect(find.text('Заказ №1044'), findsOneWidget);
    expect(find.text('Заказ №1043'), findsOneWidget);
    expect(find.text('Заказ №1042'), findsOneWidget);

    expect(find.text('Создан'), findsOneWidget);
    expect(find.text('Собираем'), findsOneWidget);
    expect(find.text('В пути'), findsOneWidget);
    expect(find.text('Доставлен'), findsOneWidget);

    expect(find.text('Отследить'), findsNWidgets(3));
    expect(find.text('Повторить заказ'), findsOneWidget);
  });

  testWidgets('repeat puts items in cart and shows snackbar', (tester) async {
    await _boot(tester, '/orders');

    await tester.tap(find.text('Повторить заказ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Товары добавлены в корзину'), findsOneWidget);
    expect(find.text('В корзину'), findsOneWidget);
    expect(DemoState.instance.cart.count, greaterThan(0));
  });

  testWidgets('order detail: timeline, courier, delivery photo', (tester) async {
    await _boot(tester, '/orders/1042');

    // Таймлайн: пять подписей.
    expect(find.text('Создан'), findsOneWidget);
    expect(find.text('Принят'), findsOneWidget);
    expect(find.text('Собираем'), findsOneWidget);
    expect(find.text('В пути'), findsOneWidget);
    expect(find.text('Доставлен'), findsWidgets);

    expect(find.text('Ахмет'), findsOneWidget);
    expect(find.text('Курьер'), findsOneWidget);
    expect(find.text('Фото доставки'), findsOneWidget);
    expect(find.text('Коробка передана на рецепцию'), findsOneWidget);
    expect(find.text('К оплате'), findsOneWidget);
  });

  testWidgets('order detail of active order pulses and offers tracking',
      (tester) async {
    await _boot(tester, '/orders/1043');

    expect(find.text('Мехмет'), findsOneWidget);
    expect(find.text('Скидка'), findsOneWidget);
    expect(find.text('KEMER10'), findsOneWidget);
    expect(find.text('Отследить'), findsOneWidget);

    // Пульсация не должна падать на прогоне кадров.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('tracking: courier moves, status reaches delivered, list follows',
      (tester) async {
    await _boot(tester, '/orders');
    await tester.tap(find.text('Отследить').at(2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Курьер в пути'), findsOneWidget);
    expect(find.text('Мехмет'), findsOneWidget);

    final before = DemoState.instance.orderById(1043);

    // Три тика по 4 секунды.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 950));
    }
    final after = DemoState.instance.orderById(1043);
    expect(after.courierLat, isNot(before.courierLat));

    // Доезжаем до конца: шаг 15% от остатка, порог 0.0025°.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 950));
    }
    expect(find.text('Курьер на месте'), findsOneWidget);

    // Назад в список — статус там обновился.
    appRouter.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));
    // 1043 доехал и 1042 уже был доставлен — две зелёные пилюли в списке.
    expect(find.text('Доставлен'), findsNWidgets(2));
    expect(find.text('Повторить заказ'), findsNWidgets(2));
  });

  testWidgets('unknown order id does not crash', (tester) async {
    await _boot(tester, '/orders/9999');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Заказ не найден'), findsOneWidget);
  });

  testWidgets('tracking of unknown order shows error, not a crash',
      (tester) async {
    await _boot(tester, '/tracking/9999');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Отслеживание'), findsOneWidget);
    expect(
      find.text('Не удалось загрузить. Проверьте соединение и попробуйте ещё раз.'),
      findsOneWidget,
    );
  });

  testWidgets('chat: quick question triggers typing and bot reply',
      (tester) async {
    await _boot(tester, '/chat');

    expect(find.text('Поддержка'), findsOneWidget);
    expect(find.text('Как оплатить?'), findsOneWidget);

    await tester.tap(find.text('Как оплатить?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Моя реплика уже в ленте, бот ещё печатает.
    expect(find.text('Как оплатить?'), findsWidgets);
    expect(find.byType(TypingBubble), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Бот'), findsWidgets);
  });

  testWidgets('chat: free text gets fallback answer', (tester) async {
    await _boot(tester, '/chat');

    await tester.enterText(find.byType(TextField), 'Привет!');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Привет!'), findsOneWidget);
    expect(find.text('Бот'), findsWidgets);
    expect(find.byType(TypingBubble), findsNothing);
  });
}

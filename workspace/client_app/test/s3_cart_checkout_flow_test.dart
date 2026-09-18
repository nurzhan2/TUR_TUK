// Приёмка воронки покупки сессии S3: корзина → чекаут → «заказ оформлен».
//
// В облачной сессии браузера нет, а сценарий из промта проверять чем-то
// надо: тест проходит ровно те шаги, которые на показе пройдёт заказчица,
// и сверяет цифры на каждом из них.
//
// Почему не `pumpAndSettle`: спиннеры анимируются бесконечно и «успокоения»
// не наступает никогда. И почему вызовы контроллера идут БЕЗ `await`:
// демо-репозитории ждут `Future.delayed`, а часы в тесте двигает только
// `pump` — `await` до первого `pump` встаёт намертво.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:client_app/app.dart';
import 'package:client_app/controllers/cart_controller.dart';
import 'package:client_app/core/demo/demo_state.dart';
import 'package:client_app/core/router/app_router.dart';
import 'package:client_app/features/cart/cart_screen.dart';
import 'package:client_app/features/catalog/catalog_screen.dart';
import 'package:client_app/features/checkout/checkout_screen.dart';
import 'package:client_app/features/checkout/order_success_screen.dart';
import 'content_setup.dart';

Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<CartController> openCart(WidgetTester tester) async {
  DemoState.instance.reset();
  // Профиль «Анастасия, Rixos Sungate, 412» — как после входа.
  DemoState.instance.signIn();
  await tester.binding.setSurfaceSize(const Size(500, 1600));
  await tester.pumpWidget(const ClientApp());
  await settle(tester);

  appRouter.go(AppRoutes.cart);
  await settle(tester);
  expect(find.byType(CartScreen), findsOneWidget);
  return Provider.of<CartController>(
    tester.element(find.byType(CartScreen)),
    listen: false,
  );
}


void main() {
  setUpAll(loadTestContent);

  testWidgets('минималка, промокод, оплата, экран успеха', (tester) async {
    final cart = await openCart(tester);
    expect(find.text('Перейти в каталог'), findsOneWidget,
        reason: 'пустая корзина');

    // 1890 ₽ — меньше минимальных 3000 ₽
    cart.add(2);
    await settle(tester);
    expect(find.byType(LinearProgressIndicator), findsOneWidget,
        reason: 'плашка минималки с прогресс-баром');
    final checkoutButton = find.widgetWithText(ElevatedButton, 'Оформить заказ');
    expect(tester.widget<ElevatedButton>(checkoutButton).onPressed, isNull,
        reason: 'кнопка оформления выключена при недоборе');

    // Степпер добирает до 3780 ₽ — плашка уходит, кнопка включается
    await tester.tap(find.byIcon(Icons.add).first);
    await settle(tester);
    expect(cart.total, 3780);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.widget<ElevatedButton>(checkoutButton).onPressed, isNotNull);
    expect(find.text('4 080 ₽'), findsWidgets, reason: '3780 + 300 доставка');

    await tester.tap(checkoutButton);
    await settle(tester);
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(find.text('Rixos Sungate'), findsWidgets, reason: 'отель из профиля');
    expect(find.text('412'), findsOneWidget, reason: 'комната из профиля');

    // EXPIRED — красная ошибка, итог не меняется
    await tester.enterText(find.byType(TextField).at(2), 'EXPIRED');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Применить'));
    await settle(tester);
    expect(find.text('Срок действия промокода истёк'), findsOneWidget);
    expect(find.text('4 080 ₽'), findsWidgets);

    // KEMER10 — ровно 10% от 3780 ₽
    await tester.enterText(find.byType(TextField).at(2), 'KEMER10');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Применить'));
    await settle(tester);
    expect(find.textContaining('Промокод применён'), findsOneWidget);
    expect(find.text('−378 ₽'), findsWidgets);
    expect(find.text('3 702 ₽'), findsWidgets);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Оплатить'));
    await settle(tester, 20);
    expect(find.byType(OrderSuccessScreen), findsOneWidget);
    expect(find.text('Заказ №1046'), findsOneWidget);
    expect(find.text('3 702 ₽'), findsOneWidget,
        reason: 'итог заказа сходится с чекаутом');
    expect(cart.count, 0, reason: 'корзина после оформления пустая');

    // Экран успеха снимается с навигатора, а не остаётся поверх каталога
    await tester.tap(find.widgetWithText(TextButton, 'В каталог'));
    await settle(tester, 20);
    expect(find.byType(OrderSuccessScreen), findsNothing);
    expect(find.byType(CatalogScreen), findsOneWidget);
  });

  testWidgets('свайп с отменой, очистка и бесплатная доставка',
      (tester) async {
    final cart = await openCart(tester);

    cart.add(3); // 2450 ₽
    await settle(tester);
    cart.add(2); // 1890 ₽ → 4340 ₽
    await settle(tester);
    expect(find.text('4 640 ₽'), findsWidgets, reason: '4340 + 300 доставка');

    await tester.drag(find.byType(Dismissible).first, const Offset(-500, 0));
    await settle(tester);
    expect(cart.count, 1, reason: 'свайп влево удаляет позицию');

    await tester.tap(find.text('Отменить'));
    await settle(tester);
    expect(cart.count, 2, reason: '«Отменить» возвращает товар');

    cart.add(11); // 2350 ₽ → 6690 ₽
    await settle(tester);
    expect(find.text('Бесплатно'), findsOneWidget,
        reason: 'доставка бесплатна от 5000 ₽');
    expect(find.text('6 690 ₽'), findsWidgets);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await settle(tester);
    expect(find.text('Все товары будут удалены из корзины.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Очистить корзину').last);
    await settle(tester);
    expect(cart.count, 0);
    expect(find.text('Перейти в каталог'), findsOneWidget);
  });
}

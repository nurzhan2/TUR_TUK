import 'package:client_app/controllers/cart_controller.dart';
import 'package:client_app/core/content/app_content.dart';
import 'package:client_app/core/demo/demo_state.dart';
import 'package:client_app/core/widgets/app_image.dart';
import 'package:client_app/core/widgets/hotel_picker.dart';
import 'package:client_app/features/cart/cart_totals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'content_setup.dart';

/// Контент из админки и правки демо-прохода (октябрь 2026).
void main() {
  setUpAll(loadTestContent);
  setUp(() => DemoState.instance.reset());

  group('корзина', () {
    test('быстрые нажатия «+» не теряются: итог — последнее значение', () async {
      final cart = CartController();
      final productId = AppContent.instance.products.first.id;
      await cart.add(productId);
      final itemId = cart.cart.items.single.id;

      // Девять тапов подряд, не дожидаясь ответа «сервера».
      final pending = <Future<void>>[];
      for (var qty = 2; qty <= 10; qty++) {
        pending.add(cart.setQuantity(itemId, qty));
        // Цифра на экране меняется сразу, до ответа.
        expect(cart.cart.items.single.quantity, qty);
      }
      await Future.wait(pending);

      expect(cart.cart.items.single.quantity, 10);
      expect(cart.count, 10);
      expect(DemoState.instance.cart.items.single.quantity, 10);
    });

    test('подсказка «до бесплатной доставки» и формула как на сервере', () {
      final d = AppContent.instance.delivery;
      final below = CartTotals(subtotal: d.freeDeliveryFrom - 1000);
      expect(below.isDeliveryFree, isFalse);
      expect(below.missingToFreeDelivery, 1000);
      expect(below.total, d.freeDeliveryFrom - 1000 + d.deliveryFee);

      final above = CartTotals(subtotal: d.freeDeliveryFrom);
      expect(above.isDeliveryFree, isTrue);
      expect(above.missingToFreeDelivery, 0);
    });

    test('порог 0 — бесплатной доставки нет (как delivery_fee_for на сервере)', () {
      const delivery = DeliverySettings(
        minOrderTotal: 0, deliveryFee: 300, freeDeliveryFrom: 0, etaMinutes: 60,
      );
      expect(delivery.feeFor(100000), 300);
    });
  });

  group('контент из админки', () {
    test('логотип с сервера важнее файла из ассетов, цвет из HEX', () {
      final brand = Brand.fromJson({
        'name': 'TUR TUK',
        'logoUrl': 'https://api.example.com/media/brand/x.webp',
        'logoFile': 'logo.png',
        'accentColor': '#123456',
      });
      expect(brand.logoFile, 'https://api.example.com/media/brand/x.webp');
      expect(brand.accentColor, const Color(0xFF123456));
      expect(brand.monogram, 'TT');
    });

    test('превью: x.webp → x.thumb.webp, остальное без изменений', () {
      expect(AppImage.thumbFor('https://a/media/p/1.webp'), 'https://a/media/p/1.thumb.webp');
      expect(AppImage.thumbFor('https://a/media/p/1.thumb.webp'), isNull);
      expect(AppImage.thumbFor('https://a/x.jpg'), isNull);
    });
  });

  testWidgets('выбор отеля: пусто по умолчанию, поиск, выбор', (tester) async {
    var selected = '';
    final hotels = AppContent.instance.hotels;
    final target = hotels.last;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => HotelPickerField(
            value: selected,
            onChanged: (v) => setState(() => selected = v),
          ),
        ),
      ),
    ));
    expect(find.text('Выберите отель'), findsOneWidget);

    await tester.tap(find.byType(HotelPickerField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), target.name.substring(0, 4));
    await tester.pumpAndSettle();
    await tester.tap(find.text(target.name).last);
    await tester.pumpAndSettle();

    expect(selected, target.name);
    expect(find.text(target.name), findsOneWidget);
  });
}

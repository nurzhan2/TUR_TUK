// Smoke-тест: приложение стартует со splash-экрана и уходит в каталог.
//
// Раньше здесь проверялся переход на экран входа. Поведение изменено
// намеренно: в демо-режиме профиль восстанавливается сам, и упереться в
// форму логина посреди показа заказчице — худший исход демонстрации.
// Вход никуда не делся, он открывается из профиля.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client_app/app.dart';
import 'content_setup.dart';


void main() {
  setUpAll(loadTestContent);

  testWidgets('splash уводит в каталог', (WidgetTester tester) async {
    await tester.pumpWidget(const ClientApp());

    // Splash сразу после первого кадра.
    expect(find.text('TUR TUK'), findsWidgets);

    // Таймер редиректа — 1200 мс, плюс загрузка демо-данных каталога.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 600));

    // На каталоге есть поле поиска — значит splash уже позади.
    expect(find.byType(TextField), findsWidgets);
  });
}

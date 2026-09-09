// Smoke-тест: приложение стартует со splash-экрана и через таймер
// переходит на экран входа по номеру телефона.

import 'package:flutter_test/flutter_test.dart';

import 'package:client_app/app.dart';

void main() {
  testWidgets('shows phone auth screen after splash redirect', (WidgetTester tester) async {
    await tester.pumpWidget(const ClientApp());

    // Splash сразу после первого кадра.
    expect(find.text('TUR TUK'), findsOneWidget);

    // Таймер редиректа на /auth — 1200 мс.
    await tester.pumpAndSettle(const Duration(milliseconds: 1500));

    expect(find.text('Вход по номеру телефона'), findsOneWidget);
    expect(find.text('Получить код'), findsOneWidget);
  });
}

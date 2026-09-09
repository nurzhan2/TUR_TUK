// Smoke-тест: приложение стартует и, без сохранённой сессии, показывает
// экран входа курьера с полем номера телефона.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courier_app/app.dart';
import 'package:courier_app/l10n/gen/app_localizations.dart';

// Тот же канал, что `MethodChannelFlutterSecureStorage`
// (flutter_secure_storage_platform_interface) — без мока в тестовом
// окружении нет платформенной стороны, вызов `read()` зависает навсегда,
// и `AuthController.restoreSession()` никогда не выходит из `AuthStatus.unknown`.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  testWidgets('shows courier auth screen on cold start', (WidgetTester tester) async {
    // Локаль тестового раннера по умолчанию не совпадает с `ru` (первым
    // preferred-supported-locales) — фиксируем её явно, иначе ожидания по
    // русскому тексту будут ломаться в зависимости от окружения CI.
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const CourierApp());
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(find.text(l10n.authTitle), findsOneWidget);
    expect(find.text(l10n.sendCodeButton), findsOneWidget);
  });
}

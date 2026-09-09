import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/cart_controller.dart';
import 'controllers/catalog_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/locale_controller.dart';
import 'controllers/orders_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/gen/app_localizations.dart';

/// Корень приложения.
///
/// Все контроллеры подняты ЗДЕСЬ, над навигатором, а не у каждого экрана.
/// Корзина обязана пережить переход между вкладками — иначе бейдж
/// обнуляется при каждом уходе с экрана корзины, — а каталог не должен
/// перезагружаться при возврате с карточки товара.
///
/// `load()` не вызывается тут же: экран сам решает, когда ему нужны данные,
/// и запускать пять загрузок разом на первом кадре значит показать пустой
/// белый экран вместо splash.
class ClientApp extends StatelessWidget {
  const ClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleController()),
        ChangeNotifierProvider(create: (_) => CatalogController()),
        ChangeNotifierProvider(create: (_) => CartController()),
        ChangeNotifierProvider(create: (_) => OrdersController()),
        ChangeNotifierProvider(create: (_) => ChatController()),
        ChangeNotifierProvider(create: (_) => AuthController()),
      ],
      child: const _App(),
    );
  }
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    // Отдельный виджет ниже MultiProvider: `context.watch` внутри того же
    // build, где провайдеры создаются, их бы ещё не нашёл.
    final locale = context.watch<LocaleController>().locale;

    return MaterialApp.router(
      title: 'TUR TUK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

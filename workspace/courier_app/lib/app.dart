import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/di.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/orders/orders_controller.dart';
import 'l10n/gen/app_localizations.dart';

/// Корневой виджет.
///
/// Репозитории берутся у [Di] — единственного места, где решается «демо или
/// бэкенд». Раньше они собирались здесь цепочкой `ProxyProvider`, и это
/// работало, пока реализация была одна; с появлением демо-режима развилка
/// в дереве провайдеров означала бы `if (kDemoMode)` посреди `build`.
class CourierApp extends StatelessWidget {
  const CourierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthController(Di.auth)..restoreSession(),
        ),
        ChangeNotifierProvider(create: (_) => OrdersController(Di.orders)),
      ],
      child: const _RouterHost(),
    );
  }
}

class _RouterHost extends StatefulWidget {
  const _RouterHost();

  @override
  State<_RouterHost> createState() => _RouterHostState();
}

class _RouterHostState extends State<_RouterHost> {
  // Построен один раз от того же `AuthController`, что живёт в дереве
  // провайдеров выше — пересоздавать `GoRouter` на каждый `build` нельзя,
  // он теряет текущий стек навигации.
  late final GoRouter _router = buildAppRouter(context.read<AuthController>());

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

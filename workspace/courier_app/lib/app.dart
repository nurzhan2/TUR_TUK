import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_repository.dart';
import 'features/orders/orders_controller.dart';
import 'features/orders/orders_repository.dart';
import 'l10n/gen/app_localizations.dart';

/// Корневой виджет: собирает зависимости (сеть -> репозитории -> контроллеры)
/// и отдаёт их через `provider` вниз по дереву, чтобы экраны не строили их
/// сами и не расходились в конфигурации (один `ApiClient` на всё приложение —
/// иначе токен, выставленный при логине, не попал бы в запросы заказов).
class CourierApp extends StatelessWidget {
  const CourierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient(), dispose: (_, client) => client.close()),
        Provider<TokenStorage>(create: (_) => TokenStorage()),
        ProxyProvider2<ApiClient, TokenStorage, AuthRepository>(
          update: (_, apiClient, tokenStorage, __) =>
              AuthRepository(apiClient: apiClient, tokenStorage: tokenStorage),
        ),
        ProxyProvider<ApiClient, OrdersRepository>(
          update: (_, apiClient, __) => OrdersRepository(apiClient: apiClient),
        ),
        ChangeNotifierProxyProvider<AuthRepository, AuthController>(
          create: (context) =>
              AuthController(repository: context.read<AuthRepository>())..restoreSession(),
          update: (_, repository, previous) => previous!,
        ),
        ChangeNotifierProxyProvider<OrdersRepository, OrdersController>(
          create: (context) => OrdersController(repository: context.read<OrdersRepository>()),
          update: (_, repository, previous) => previous!,
        ),
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
      theme: AppTheme.light(),
      routerConfig: _router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

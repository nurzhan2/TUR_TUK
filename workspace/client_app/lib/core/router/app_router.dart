import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/catalog/catalog_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/orders/order_detail_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/product/product_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/tracking/tracking_screen.dart';
import '../widgets/main_shell.dart';

/// Пути маршрутов и хелперы к ним.
///
/// Отдельный класс, чтобы путь не расползался строками-литералами по фичам:
/// шесть сессий пишут экраны одновременно, и `'/orders/' + id` в одной из
/// них разошёлся бы с настоящим маршрутом молча — до первого нажатия.
class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const auth = '/auth';
  static const catalog = '/catalog';
  static const product = '/catalog/product/:id';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const orderDetail = '/orders/:id';
  static const tracking = '/tracking/:id';
  static const chat = '/chat';
  static const profile = '/profile';

  static String productPath(int id) => '/catalog/product/$id';

  static String orderPath(int id) => '/orders/$id';

  static String trackingPath(int id) => '/tracking/$id';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

/// Номер из пути. `:id` в go_router всегда строка, а экраны работают с
/// числом — разбор стоит ЗДЕСЬ, в одном месте, а не в каждом экране.
/// Мусор в адресе (`/orders/abc`) даёт 0, и экран честно покажет «не
/// найдено» вместо падения на `int.parse`.
int _idOf(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

/// Редиректа по авторизации здесь НЕТ намеренно.
///
/// Демо показывают заказчице, и упереться в экран входа посреди показа —
/// худшее, что может случиться: каталог, корзина и заказы должны
/// открываться сразу. Вход остаётся отдельным экраном и работает, когда
/// на него приходят своим ходом со splash.
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.auth,
      builder: (context, state) => const AuthScreen(),
    ),
    // Чекаут, чат и трекинг открываются ПОВЕРХ каркаса, без нижней
    // навигации: это сквозные сценарии, из которых уходят «назад»,
    // а не разделы, между которыми переключаются.
    GoRoute(
      path: AppRoutes.checkout,
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(
      path: AppRoutes.chat,
      builder: (context, state) => const ChatScreen(),
    ),
    GoRoute(
      path: AppRoutes.tracking,
      builder: (context, state) => TrackingScreen(orderId: _idOf(state)),
    ),
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.catalog,
          builder: (context, state) => const CatalogScreen(),
          routes: [
            GoRoute(
              path: 'product/:id',
              builder: (context, state) => ProductScreen(productId: _idOf(state)),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.cart,
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: AppRoutes.orders,
          builder: (context, state) => const OrdersScreen(),
          routes: [
            // Вложенный маршрут, а не отдельный `/orders/:id`: так «назад»
            // с карточки заказа возвращает в список, а не выбрасывает
            // на стартовый экран.
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  OrderDetailScreen(orderId: _idOf(state)),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);

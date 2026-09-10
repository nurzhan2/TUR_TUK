import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/courier_auth_screen.dart';
import '../../features/orders/delivery_confirm_screen.dart';
import '../../features/orders/order_detail_screen.dart';
import '../../features/orders/orders_list_screen.dart';
import '../../features/orders/route_map_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const auth = '/auth';
  static const orders = '/orders';
  static const orderDetail = '/orders/:id';
  static const orderDelivery = '/orders/:id/delivery';
  static const orderRoute = '/orders/:id/route';

  static String orderPath(int id) => '/orders/$id';

  static String deliveryPath(int id) => '/orders/$id/delivery';

  static String routePath(int id) => '/orders/$id/route';
}

/// Номер из пути. `:id` в go_router всегда строка, а экраны работают с
/// числом — разбор стоит в одном месте, а не в каждом экране. Мусор в
/// адресе даёт 0, и экран честно покажет «заказ не найден» вместо падения
/// на `int.parse`.
int _idOf(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

/// `GoRouter` с редиректом по состоянию [AuthController] — единственное
/// место, решающее, пускать ли на защищённые экраны. `refreshListenable`
/// перестраивает маршрут при каждом `notifyListeners()` контроллера, поэтому
/// логин/логаут не нужно дублировать явной навигацией из экранов.
///
/// Детали, подтверждение доставки и карта — ВЛОЖЕННЫЕ маршруты списка:
/// так системная кнопка «назад» с карты возвращает в карточку заказа,
/// а с карточки — в список, а не выбрасывает курьера в начало.
GoRouter buildAppRouter(AuthController authController) {
  return GoRouter(
    initialLocation: AppRoutes.auth,
    refreshListenable: authController,
    routes: [
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const CourierAuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) => const OrdersListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                OrderDetailScreen(orderId: _idOf(state)),
            routes: [
              GoRoute(
                path: 'delivery',
                builder: (context, state) =>
                    DeliveryConfirmScreen(orderId: _idOf(state)),
              ),
              GoRoute(
                path: 'route',
                builder: (context, state) =>
                    RouteMapScreen(orderId: _idOf(state)),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final status = authController.status;
      if (status == AuthStatus.unknown) return null;

      final loggedIn = status == AuthStatus.authenticated;
      final onAuthRoute = state.matchedLocation == AppRoutes.auth;

      if (!loggedIn && !onAuthRoute) return AppRoutes.auth;
      if (loggedIn && onAuthRoute) return AppRoutes.orders;
      return null;
    },
  );
}

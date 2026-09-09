import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/courier_auth_screen.dart';
import '../../features/orders/orders_list_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const auth = '/auth';
  static const orders = '/orders';
}

/// `GoRouter` с редиректом по состоянию [AuthController] — единственное
/// место, решающее, пускать ли на защищённые экраны. `refreshListenable`
/// перестраивает маршрут при каждом `notifyListeners()` контроллера, поэтому
/// логин/логаут не нужно дублировать явной навигацией из экранов.
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

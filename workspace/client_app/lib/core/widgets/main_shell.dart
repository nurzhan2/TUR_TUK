import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/cart_controller.dart';
import '../../l10n/gen/app_localizations.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

/// Каркас с нижней навигацией: «Каталог», «Корзина», «Заказы», «Профиль».
class MainShell extends StatelessWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  static const _routes = [
    AppRoutes.catalog,
    AppRoutes.cart,
    AppRoutes.orders,
    AppRoutes.profile,
  ];

  /// Активная вкладка — по САМОМУ ДЛИННОМУ совпавшему префиксу.
  ///
  /// Наивный `indexWhere(startsWith)` ошибается на `/catalog/product/7`:
  /// он совпадает и с `/catalog`, и — если порядок вкладок изменят — может
  /// совпасть не с тем. Длиннейший префикс отвечает на вопрос «в каком
  /// разделе я сейчас» однозначно.
  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    var best = 0;
    var bestLength = -1;
    for (var i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      if (location == route || location.startsWith('$route/')) {
        if (route.length > bestLength) {
          best = i;
          bestLength = route.length;
        }
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // watch, а не read: бейдж обязан меняться в тот же кадр, в который
    // товар лёг в корзину, — иначе «в корзину» выглядит как несработавшее.
    final count = context.watch<CartController>().count;
    final labels = [
      l10n.catalogTitle,
      l10n.cartTitle,
      l10n.ordersTitle,
      l10n.profileTitle,
    ];
    const icons = [
      Icons.storefront_outlined,
      Icons.shopping_cart_outlined,
      Icons.receipt_long_outlined,
      Icons.person_outline,
    ];
    const activeIcons = [
      Icons.storefront,
      Icons.shopping_cart,
      Icons.receipt_long,
      Icons.person,
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex(context),
            onTap: (index) => context.go(_routes[index]),
            items: [
              for (var i = 0; i < _routes.length; i++)
                BottomNavigationBarItem(
                  icon: _TabIcon(icon: icons[i], badge: i == 1 ? count : 0),
                  activeIcon:
                      _TabIcon(icon: activeIcons[i], badge: i == 1 ? count : 0),
                  label: labels[i],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Иконка вкладки со счётчиком. Ноль означает «бейджа нет»: кружок с «0»
/// сообщает ровно то же, что его отсутствие, но занимает место и тянет
/// на себя взгляд.
class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.icon, required this.badge});

  final IconData icon;
  final int badge;

  @override
  Widget build(BuildContext context) {
    if (badge <= 0) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          top: -4,
          right: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 17),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.background, width: 1.5),
            ),
            child: Text(
              // Трёхзначный счётчик разъезжается по ширине вкладки, а «99+»
              // отвечает на тот же вопрос: «много».
              badge > 99 ? '99+' : '$badge',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

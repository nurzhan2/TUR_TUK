import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

/// Корзина. Минимальная сумма заказа 3000 ₽ проверяется здесь, когда
/// появится реальный расчёт стоимости.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Корзина')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => context.push(AppRoutes.checkout),
          child: const Text('Оформить заказ'),
        ),
      ),
    );
  }
}

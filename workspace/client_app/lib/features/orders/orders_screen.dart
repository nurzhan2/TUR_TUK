import 'package:flutter/material.dart';

/// История заказов с отслеживанием статуса и повтором заказа.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои заказы')),
      body: const Center(child: Text('Заказов пока нет')),
    );
  }
}

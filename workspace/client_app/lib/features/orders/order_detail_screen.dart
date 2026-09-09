import 'package:flutter/material.dart';

/// ЗАГЛУШКА. Экран карточки заказа пишет другая сессия — этот файл заведён
/// только затем, чтобы маршрут `/orders/:id` собирался, и будет перезаписан.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Заказ №$orderId')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

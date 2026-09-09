import 'package:flutter/material.dart';

/// ЗАГЛУШКА. Экран отслеживания пишет другая сессия — этот файл заведён
/// только затем, чтобы маршрут `/tracking/:id` собирался, и будет перезаписан.
class TrackingScreen extends StatelessWidget {
  const TrackingScreen({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Отслеживание')),
      body: Center(child: Text('Заказ №$orderId')),
    );
  }
}

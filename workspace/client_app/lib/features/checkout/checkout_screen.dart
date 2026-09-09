import 'package:flutter/material.dart';

/// Оформление заказа: отель, номер комнаты, оплата картой/СБП (ЮKassa).
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оформление заказа')),
      body: const Center(child: Text('Оплата: карта / СБП')),
    );
  }
}

import 'package:flutter/material.dart';

/// Карточка товара: фото, описание, цена (ТЗ, стиль Wildberries).
class ProductScreen extends StatelessWidget {
  const ProductScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Товар $productId')),
      body: const Center(child: Text('Карточка товара')),
    );
  }
}

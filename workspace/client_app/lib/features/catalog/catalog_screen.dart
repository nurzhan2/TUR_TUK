import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

/// Каталог с поиском и категориями (ТЗ: карточки товаров в стиле
/// Wildberries). Данные и сетка карточек — отдельная задача, здесь только
/// каркас экрана и переход на карточку товара.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TUR TUK'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push(AppRoutes.chat),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TextField(
                decoration: InputDecoration(
                  hintText: 'Поиск товаров',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: TextButton(
                    onPressed: () => context.push(AppRoutes.productPath('demo')),
                    child: const Text('Открыть карточку товара (демо)'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

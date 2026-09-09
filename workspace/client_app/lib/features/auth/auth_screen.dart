import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

/// Регистрация по номеру телефона + SMS-код (ТЗ: deliverables, must).
/// Здесь только каркас экрана — интеграция с бэкендом и SMS-провайдером
/// появится отдельной задачей, вместе с `AuthController`, как в
/// `courier_app`.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Вход по номеру телефона', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              const TextField(
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Номер телефона',
                  prefixText: '+',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.catalog),
                child: const Text('Получить код'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

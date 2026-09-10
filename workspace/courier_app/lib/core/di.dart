import '../features/auth/auth_repository.dart';
import '../features/orders/orders_repository.dart';
import 'demo/demo_mode.dart';
import 'network/api_client.dart';
import 'storage/token_storage.dart';

/// Единственное место, где решается «демо или бэкенд».
///
/// Тот же приём, что в клиентском приложении (`client_app/lib/core/di.dart`):
/// развилка стоит ЗДЕСЬ, а не в экранах и контроллерах. `if (kDemoMode)`,
/// разбросанный по виджетам, — способ однажды забыть один из них и показать
/// заказчице ошибку сети посреди демонстрации. Выше уровня [Di] о
/// существовании демо-режима не знает никто.
///
/// Геттеры ленивые и кешируют экземпляр: у боевых репозиториев общий
/// [ApiClient] с токеном, и пересоздавать их на каждое обращение значило бы
/// терять авторизацию сразу после входа.
class Di {
  const Di._();

  static ApiClient? _api;
  static TokenStorage? _tokens;
  static AuthRepository? _auth;
  static OrdersRepository? _orders;

  static ApiClient get api => _api ??= ApiClient();

  static TokenStorage get tokens => _tokens ??= TokenStorage();

  static AuthRepository get auth => _auth ??= kDemoMode
      ? const DemoAuthRepository()
      : ApiAuthRepository(apiClient: api, tokenStorage: tokens);

  static OrdersRepository get orders => _orders ??= kDemoMode
      ? const DemoOrdersRepository()
      : ApiOrdersRepository(apiClient: api);

  /// Подмена реализаций — для тестов. Публичный вход вместо присваивания
  /// полям: поля приватные, а через один метод видно, кто и что подменил.
  static void override({
    AuthRepository? auth,
    OrdersRepository? orders,
  }) {
    if (auth != null) _auth = auth;
    if (orders != null) _orders = orders;
  }

  static void reset() {
    _api?.close();
    _api = null;
    _tokens = null;
    _auth = null;
    _orders = null;
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/auth_repository.dart';
import '../data/cart_repository.dart';
import '../data/catalog_repository.dart';
import '../data/chat_repository.dart';
import '../data/orders_repository.dart';
import '../data/promo_repository.dart';
import 'demo/demo_mode.dart';
import 'network/api_client.dart';

/// Единственное место, где решается «демо или бэкенд».
///
/// Развилка стоит ЗДЕСЬ, а не в экранах и контроллерах: `if (kDemoMode)`,
/// разбросанный по виджетам, — это способ однажды забыть один из них
/// и показать заказчице пустой экран с ошибкой сети посреди демонстрации.
/// Выше уровня `Di` о существовании демо-режима не знает никто.
///
/// Геттеры ЛЕНИВЫЕ и кешируют экземпляр: у демо-репозиториев есть
/// состояние (broadcast-поток чата, токен авторизации), и пересоздавать
/// их на каждое обращение значило бы терять подписки.
class Di {
  const Di._();

  static CatalogRepository? _catalog;
  static CartRepository? _cart;
  static OrdersRepository? _orders;
  static PromoRepository? _promo;
  static ChatRepository? _chat;
  static AuthRepository? _auth;
  static ApiClient? _api;

  static ApiClient get api => _api ??= ApiClient();

  // Каталог читается из AppContent: он загружен из `GET /app/config` (или из
  // ассетов в демо без сервера) — одна точка правды для витрины.
  static CatalogRepository get catalog => _catalog ??= kDemoMode || kContentFromApi
      ? const DemoCatalogRepository()
      : ApiCatalogRepository(api);

  static CartRepository get cart =>
      _cart ??= kDemoMode ? const DemoCartRepository() : ApiCartRepository(api);

  static OrdersRepository get orders => _orders ??=
      kDemoMode ? const DemoOrdersRepository() : ApiOrdersRepository(api);

  // Промокоды живут в админке: когда контент приходит с сервера, проверка
  // тоже идёт туда (`POST /promo/validate` публичный, токен не нужен).
  static PromoRepository get promo => _promo ??= kDemoMode && !kContentFromApi
      ? const DemoPromoRepository()
      : ApiPromoRepository(api);

  static ChatRepository get chat =>
      _chat ??= kDemoMode ? DemoChatRepository() : ApiChatRepository(api);

  static AuthRepository get auth => _auth ??= kDemoMode
      ? const DemoAuthRepository()
      : ApiAuthRepository(api, const SecureTokenStorage());

  /// Подмена реализаций — для тестов и для отладки боевого режима на демо.
  /// Публичный сеттер вместо «просто присвоить полю»: поля приватные,
  /// а через один вход видно, кто и что подменил.
  static void override({
    CatalogRepository? catalog,
    CartRepository? cart,
    OrdersRepository? orders,
    PromoRepository? promo,
    ChatRepository? chat,
    AuthRepository? auth,
  }) {
    if (catalog != null) _catalog = catalog;
    if (cart != null) _cart = cart;
    if (orders != null) _orders = orders;
    if (promo != null) _promo = promo;
    if (chat != null) _chat = chat;
    if (auth != null) _auth = auth;
  }

  static void reset() {
    _catalog = null;
    _cart = null;
    _orders = null;
    _promo = null;
    _chat = null;
    _auth = null;
    _api = null;
  }
}

/// Токен в защищённом хранилище ОС: Keychain на iOS, EncryptedSharedPreferences
/// на Android. `SharedPreferences` тут не годится — это открытый XML в
/// песочнице приложения, и на рутованном устройстве токен читается как есть.
class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage();

  static const _key = 'turtuk_access_token';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> save(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

import '../../core/demo/demo_mode.dart';
import '../../core/demo/demo_state.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';

/// Пара токенов, как их отдаёт `POST /auth/verify-code`
/// (`TokenResponse` в `backend/app/schemas/auth.py`).
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
  );

  final String accessToken;
  final String refreshToken;
}

/// Вход курьера. Реализаций две — демо и боевая, выбор стоит в [Di].
abstract class AuthRepository {
  Future<void> sendCode(String phone);

  /// Неверный код поднимает [ApiException]: `AuthController` показывает
  /// `detail` под полем. Отдельного `bool` в контракте нет намеренно —
  /// ошибка сети и неверный код должны доходить до экрана одним путём.
  Future<void> verifyCode({required String phone, required String code});

  /// Токен сохранённой сессии, `null` — сессии нет. В демо возвращает
  /// строку-заглушку: роутеру важен только факт входа.
  Future<String?> restoreSession();

  Future<void> logout();
}

/// Демо-вход: любой телефон и любые четыре цифры.
///
/// Длину кода всё же проверяем — поле, принимающее пустую строку, читается
/// как неработающая форма, и это первое, что заметят на показе. Называть
/// «правильный» код на экране нельзя: это выглядит как отладочная заглушка.
class DemoAuthRepository implements AuthRepository {
  const DemoAuthRepository();

  @override
  Future<void> sendCode(String phone) async {
    await Future<void>.delayed(kDemoLatency);
    DemoState.instance.pendingPhone = phone;
  }

  @override
  Future<void> verifyCode({
    required String phone,
    required String code,
  }) async {
    await Future<void>.delayed(kDemoLatency);
    if (!RegExp(r'^\d{4}$').hasMatch(code.trim())) {
      // Тот же путь, что у боевой реализации: контроллер покажет ключ
      // `authInvalidCode` под полем.
      throw ApiException(400, 'authInvalidCode');
    }
    DemoState.instance.signIn();
  }

  @override
  Future<String?> restoreSession() async {
    await Future<void>.delayed(kDemoLatency);
    // Показ начинается с экрана входа: заказчице надо увидеть, как курьер
    // входит, а не открыть готовый список заказов.
    return DemoState.instance.signedIn ? 'demo-session' : null;
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(kDemoLatency);
    DemoState.instance.signOut();
  }
}

/// Тот же SMS-контур, что у клиентского приложения (одни и те же
/// `/auth/send-code` и `/auth/verify-code`, см. `backend/app/api/auth.py`).
///
/// Роль курьера бэкенд отдельно не выдаёт: `verify_sms_code()` заводит
/// НОВОГО пользователя всегда с ролью `client`, а курьеров заводит владелец
/// заранее с ролью `courier` на тот же номер телефона — тогда `verify-code`
/// находит существующего пользователя и просто выдаёт ему токен. Это
/// ограничение сегодняшнего бэкенда, не этого экрана: см. `docs/DECISIONS.md`.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  }) : _apiClient = apiClient,
       _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  @override
  Future<void> sendCode(String phone) async {
    await _apiClient.post(
      '/auth/send-code',
      body: {'phone': phone},
      withAuth: false,
    );
  }

  @override
  Future<void> verifyCode({
    required String phone,
    required String code,
  }) async {
    final json =
        await _apiClient.post(
              '/auth/verify-code',
              body: {'phone': phone, 'code': code},
              withAuth: false,
            )
            as Map<String, dynamic>;

    final tokens = AuthTokens.fromJson(json);
    await _tokenStorage.save(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    _apiClient.accessToken = tokens.accessToken;
  }

  @override
  Future<String?> restoreSession() async {
    final token = await _tokenStorage.readAccessToken();
    _apiClient.accessToken = token;
    return token;
  }

  @override
  Future<void> logout() async {
    await _tokenStorage.clear();
    _apiClient.accessToken = null;
  }
}

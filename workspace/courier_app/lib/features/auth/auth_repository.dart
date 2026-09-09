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

/// Тот же SMS-контур, что у клиентского приложения (одни и те же
/// `/auth/send-code` и `/auth/verify-code`, см. `backend/app/api/auth.py`).
///
/// Роль курьера бэкенд отдельно не выдаёт: `verify_sms_code()` заводит
/// НОВОГО пользователя всегда с ролью `client`, а курьеров заводит владелец
/// заранее (через админку) с ролью `courier` на тот же номер телефона —
/// тогда `verify-code` находит существующего пользователя и просто выдаёт
/// ему токен. Это ограничение сегодняшнего бэкенда, не этого экрана: см.
/// `docs/DECISIONS.md`.
class AuthRepository {
  AuthRepository({required ApiClient apiClient, required TokenStorage tokenStorage})
      : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<void> sendCode(String phone) async {
    await _apiClient.post('/auth/send-code', body: {'phone': phone}, withAuth: false);
  }

  Future<AuthTokens> verifyCode({required String phone, required String code}) async {
    final json = await _apiClient.post(
      '/auth/verify-code',
      body: {'phone': phone, 'code': code},
      withAuth: false,
    ) as Map<String, dynamic>;

    final tokens = AuthTokens.fromJson(json);
    await _tokenStorage.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
    _apiClient.accessToken = tokens.accessToken;
    return tokens;
  }

  Future<String?> restoreSession() async {
    final token = await _tokenStorage.readAccessToken();
    _apiClient.accessToken = token;
    return token;
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    _apiClient.accessToken = null;
  }
}

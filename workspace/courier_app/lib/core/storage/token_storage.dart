import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Хранилище JWT-токенов курьера. Секретов вроде паролей приложение не
/// собирает — только пара access/refresh, выданная `/auth/verify-code`
/// (см. `backend/app/api/auth.py`). Хранится через platform keystore/keychain,
/// не в SharedPreferences.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'courier_access_token';
  static const _refreshKey = 'courier_refresh_token';

  final FlutterSecureStorage _storage;

  Future<void> save({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

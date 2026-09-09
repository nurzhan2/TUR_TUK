import '../core/demo/demo_data.dart';
import '../core/demo/demo_state.dart';
import '../core/network/api_client.dart';
import '../models/user_profile.dart';
import 'catalog_repository.dart' show kDemoLatency;

abstract class AuthRepository {
  Future<void> sendCode(String phone);

  Future<bool> verifyCode(String phone, String code);

  Future<UserProfile> register({
    required String name,
    required String hotelName,
    required String roomNumber,
    DateTime? dob,
  });

  Future<UserProfile?> currentUser();

  Future<void> logout();
}

class DemoAuthRepository implements AuthRepository {
  const DemoAuthRepository();

  @override
  Future<void> sendCode(String phone) async {
    await Future<void>.delayed(kDemoLatency);
    DemoState.instance.pendingPhone = phone;
  }

  /// Любой код из четырёх цифр подходит. Показ идёт без SMS-шлюза, и
  /// единственная альтернатива — назвать «правильный» код на экране, что
  /// выглядит как отладочная заглушка. Длину при этом проверяем: поле,
  /// принимающее пустую строку, читается как неработающая форма.
  @override
  Future<bool> verifyCode(String phone, String code) async {
    await Future<void>.delayed(kDemoLatency);
    final digits = code.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(digits)) return false;
    DemoState.instance.signIn(DemoData.profile.copyWith(phone: phone));
    return true;
  }

  @override
  Future<UserProfile> register({
    required String name,
    required String hotelName,
    required String roomNumber,
    DateTime? dob,
  }) async {
    await Future<void>.delayed(kDemoLatency);
    final phone = DemoState.instance.pendingPhone ?? DemoData.profile.phone;
    return DemoState.instance.signIn(UserProfile(
      name: name,
      phone: phone,
      hotelName: hotelName,
      roomNumber: roomNumber,
      dob: dob,
    ));
  }

  @override
  Future<UserProfile?> currentUser() async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.user;
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(kDemoLatency);
    DemoState.instance.signOut();
  }
}

/// Боевая авторизация: `backend/app/api/auth.py`.
///
/// Токен кладётся в [ApiClient.accessToken] и в защищённое хранилище —
/// без второго клиент разлогинивается при каждом запуске приложения.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  UserProfile? _cached;

  @override
  Future<void> sendCode(String phone) async {
    await _api.post('/auth/send-code', body: {'phone': phone}, withAuth: false);
  }

  @override
  Future<bool> verifyCode(String phone, String code) async {
    try {
      final body = await _api.post(
        '/auth/verify-code',
        body: {'phone': phone, 'code': code},
        withAuth: false,
      ) as Map<String, dynamic>;
      final token = body['access_token'] as String;
      _api.accessToken = token;
      await _storage.save(token);
      return true;
    } on ApiException {
      // Неверный код — это НЕ авария, а обычный исход формы: экран
      // показывает «неверный код» под полем. Ошибка сети при этом
      // остаётся исключением и долетает до контроллера.
      return false;
    }
  }

  @override
  Future<UserProfile> register({
    required String name,
    required String hotelName,
    required String roomNumber,
    DateTime? dob,
  }) async {
    final body = await _api.post('/auth/register', body: {
      'name': name,
      'hotel_name': hotelName,
      'room_number': roomNumber,
      // `dob` на бэкенде обязателен (`RegisterRequest.dob: date`), но
      // в форме он необязательный — подставлять выдуманную дату нельзя,
      // поэтому её отсутствие увидит именно бэкенд и ответит 422.
      if (dob != null) 'dob': dob.toIso8601String().split('T').first,
    }) as Map<String, dynamic>;
    _cached = UserProfile.fromJson(body);
    return _cached!;
  }

  /// ИЗВЕСТНЫЙ ПРОБЕЛ: эндпоинта «кто я» на бэкенде нет — в `app/api/auth.py`
  /// только `send-code`, `verify-code` и `register`. Поэтому профиль здесь
  /// живёт ровно столько, сколько живёт процесс: сохранённый токен вернёт
  /// пользователя в приложение, но имя и отель придётся спросить заново.
  /// Придумывать несуществующий `GET /auth/me` хуже: он молча упадёт 404
  /// на первом же живом запуске.
  @override
  Future<UserProfile?> currentUser() async {
    if (_cached != null) return _cached;
    final token = await _storage.read();
    if (token == null) return null;
    _api.accessToken = token;
    return null;
  }

  @override
  Future<void> logout() async {
    _cached = null;
    _api.accessToken = null;
    await _storage.clear();
  }
}

/// Хранилище токена. Отдельным интерфейсом, чтобы `flutter_secure_storage`
/// не тянулся в тесты: на десктопе и в CI он требует нативной части,
/// которой там нет.
abstract class TokenStorage {
  Future<String?> read();

  Future<void> save(String token);

  Future<void> clear();
}

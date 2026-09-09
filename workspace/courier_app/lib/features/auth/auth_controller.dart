import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'auth_repository.dart';

enum AuthStatus { unknown, phoneEntry, codeEntry, authenticated }

/// Состояние экрана входа + факт авторизации для роутера (`GoRouter` читает
/// [status], чтобы решить, пускать ли на защищённые маршруты — см.
/// `core/router/app_router.dart`).
class AuthController extends ChangeNotifier {
  AuthController({required AuthRepository repository}) : _repository = repository;

  final AuthRepository _repository;

  AuthStatus status = AuthStatus.unknown;
  String phone = '';
  bool isLoading = false;
  String? errorMessage;

  Future<void> restoreSession() async {
    // Хранилище токенов — платформенный keystore/keychain; если он временно
    // недоступен (например, первый запуск на некоторых Android-сборках),
    // безопаснее считать сессию отсутствующей и отправить на вход, чем
    // оставить экран в вечной загрузке.
    String? token;
    try {
      token = await _repository.restoreSession();
    } catch (_) {
      token = null;
    }
    status = token == null ? AuthStatus.phoneEntry : AuthStatus.authenticated;
    notifyListeners();
  }

  Future<bool> sendCode(String phone) async {
    this.phone = phone;
    return _run(() async {
      await _repository.sendCode(phone);
      status = AuthStatus.codeEntry;
    });
  }

  Future<bool> verifyCode(String code) async {
    return _run(() async {
      await _repository.verifyCode(phone: phone, code: code);
      status = AuthStatus.authenticated;
    });
  }

  void backToPhoneEntry() {
    status = AuthStatus.phoneEntry;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await _repository.logout();
    phone = '';
    status = AuthStatus.phoneEntry;
    notifyListeners();
  }

  /// Общий обвес для обоих шагов входа: сбрасывает прошлую ошибку, включает
  /// индикатор загрузки, превращает [ApiException] в текст для экрана.
  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.detail;
      return false;
    } catch (_) {
      errorMessage = 'network_error';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

import 'package:flutter/foundation.dart';

import '../core/di.dart';
import '../models/user_profile.dart';
import 'controller_state.dart';

class AuthController extends ChangeNotifier {
  ControllerState state = ControllerState.initial;
  String? errorMessage;

  UserProfile? profile;

  bool get isAuthorized => profile != null;

  /// Телефон, на который отправлен код. Экран ввода кода показывает его,
  /// чтобы человек видел, куда пришла смс, и мог вернуться и исправить.
  String? phone;

  Future<void> load() async {
    state = ControllerState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      profile = await Di.auth.currentUser();
      state = ControllerState.loaded;
    } catch (error) {
      state = ControllerState.error;
      errorMessage = '$error';
    }
    notifyListeners();
  }

  Future<void> sendCode(String phone) async {
    this.phone = phone;
    state = ControllerState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      await Di.auth.sendCode(phone);
      state = ControllerState.loaded;
    } catch (error) {
      state = ControllerState.error;
      errorMessage = '$error';
    }
    notifyListeners();
  }

  /// `false` — код не подошёл. Это ОБЫЧНЫЙ исход формы, а не ошибка
  /// загрузки: экран подсвечивает поле, а не показывает «повторить».
  /// Поэтому неверный код не выставляет `state = error`.
  Future<bool> verifyCode(String code) async {
    final target = phone;
    if (target == null) return false;
    state = ControllerState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final ok = await Di.auth.verifyCode(target, code);
      if (ok) profile = await Di.auth.currentUser();
      state = ControllerState.loaded;
      notifyListeners();
      return ok;
    } catch (error) {
      state = ControllerState.error;
      errorMessage = '$error';
      notifyListeners();
      return false;
    }
  }

  Future<void> register({
    required String name,
    required String hotelName,
    required String roomNumber,
    DateTime? dob,
  }) async {
    state = ControllerState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      profile = await Di.auth.register(
        name: name,
        hotelName: hotelName,
        roomNumber: roomNumber,
        dob: dob,
      );
      state = ControllerState.loaded;
    } catch (error) {
      state = ControllerState.error;
      errorMessage = '$error';
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await Di.auth.logout();
    profile = null;
    phone = null;
    state = ControllerState.initial;
    notifyListeners();
  }
  /// Удалить аккаунт. Ошибку (нет сети) пробрасываем — экран покажет её,
  /// и гость не решит, что данные удалены, когда это не так.
  Future<void> deleteAccount() async {
    await Di.auth.deleteAccount();
    profile = null;
    phone = null;
    state = ControllerState.initial;
    notifyListeners();
  }
}

import 'package:flutter/material.dart';

import 'controller_state.dart';

/// Язык интерфейса: русский, английский, турецкий.
///
/// Русский по умолчанию — клиенты TUR TUK это русскоязычные туристы
/// в Кемере, и именно с ними работает служба доставки. Системная локаль
/// НЕ подставляется: телефон, купленный в Турции, встретил бы гостью
/// турецким интерфейсом.
class LocaleController extends ChangeNotifier {
  ControllerState state = ControllerState.loaded;
  String? errorMessage;

  Locale locale = const Locale('ru');

  static const List<Locale> supported = [
    Locale('ru'),
    Locale('en'),
    Locale('tr'),
  ];

  /// Есть у всех контроллеров по контракту. Язык брать неоткуда — он живёт
  /// в памяти, — поэтому здесь это осознанно пустой метод, а не забытая
  /// заготовка: настройка не переживает перезапуск, и в демо так и надо.
  Future<void> load() async {}

  void setLocale(Locale value) {
    if (locale == value) return;
    locale = value;
    notifyListeners();
  }
}

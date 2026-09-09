/// Адрес бэкенда TUR TUK (см. `backend/app/api/auth.py` и остальные роутеры).
///
/// По умолчанию — адрес хоста с Android-эмулятора (`10.0.2.2` смотрит на
/// `localhost` машины разработчика). Для реального устройства, iOS-симулятора
/// или прод-сервера передаётся флагом сборки, без правки кода:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=https://api.turtuk.example.com
/// ```
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}

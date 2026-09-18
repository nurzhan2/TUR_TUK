import 'package:client_app/core/content/app_content.dart';
import 'package:flutter_test/flutter_test.dart';

/// Загрузка контента для тестов.
///
/// Каталог, отели и суммы доставки приложение читает из ассетов при старте
/// (`main()` делает это до `runApp`). В тестах `main()` не выполняется,
/// поэтому каждый файл с тестами обязан позвать это в `setUpAll`, иначе
/// первое же обращение к `AppContent.instance` бросит `StateError`.
Future<void> loadTestContent() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppContent.load();
}

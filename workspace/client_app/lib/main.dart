import 'package:flutter/material.dart';

import 'app.dart';
import 'core/content/app_content.dart';

Future<void> main() async {
  // Каталог, отели, промокоды и суммы доставки лежат в ассетах, а не в коде:
  // читаем их до первого кадра, чтобы экраны не мигали пустотой.
  WidgetsFlutterBinding.ensureInitialized();
  await AppContent.load();
  runApp(const ClientApp());
}

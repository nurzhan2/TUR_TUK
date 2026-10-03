import 'package:flutter/material.dart';

import 'app.dart';
import 'core/content/app_content.dart';

Future<void> main() async {
  // Каталог, цены, отели, суммы доставки и бренд приходят из админки
  // (`GET /app/config`) — читаем их до первого кадра, чтобы экраны не
  // мигали пустотой.
  WidgetsFlutterBinding.ensureInitialized();
  if (await AppContent.load()) {
    runApp(const ClientApp());
  } else {
    runApp(const _OfflineBootApp());
  }
}

/// Боевая сборка не смогла получить каталог: показывать гостю пустой или
/// вымышленный магазин нельзя, поэтому — понятный экран и «Повторить».
class _OfflineBootApp extends StatefulWidget {
  const _OfflineBootApp();

  @override
  State<_OfflineBootApp> createState() => _OfflineBootAppState();
}

class _OfflineBootAppState extends State<_OfflineBootApp> {
  bool _loading = false;

  Future<void> _retry() async {
    setState(() => _loading = true);
    if (await AppContent.load()) {
      runApp(const ClientApp());
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8B0000);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: accent, useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 56, color: accent),
                  const SizedBox(height: 20),
                  const Text(
                    'Нет связи с магазином',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Проверьте интернет — Wi-Fi отеля или мобильные данные — и попробуйте ещё раз.\n'
                    'No connection. Check Wi-Fi or mobile data and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      minimumSize: const Size(220, 52),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _loading ? null : _retry,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(_loading ? 'Подключаемся…' : 'Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

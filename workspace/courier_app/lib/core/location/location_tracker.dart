import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../network/api_config.dart';

/// Почему трекинг не запустился — экран показывает курьеру понятную причину.
enum TrackingProblem { serviceDisabled, permissionDenied, permissionForever }

/// Отправка координат курьера по заказу в `WS /ws/courier-location/{id}`.
///
/// Пока заказ «в пути», клиент видит курьера на карте. Сервер принимает
/// `{"lat": .., "lon": ..}` только от курьера, назначенного на заказ.
///
/// * Android: foreground service с постоянным уведомлением «Идёт доставка» —
///   без него система останавливает геолокацию вскоре после блокировки
///   экрана (Android 8+).
/// * iOS: фоновые обновления (`UIBackgroundModes: location`) с синим
///   индикатором в статус-баре, как требует App Store.
/// * Связь рвётся (лифт, подвал отеля): переподключение с паузой до 30 с,
///   последняя точка отправляется сразу после восстановления.
class LocationTracker {
  LocationTracker._();

  static final LocationTracker instance = LocationTracker._();

  int? _orderId;
  String? _token;
  StreamSubscription<Position>? _positions;
  WebSocketChannel? _socket;
  Timer? _reconnect;
  int _attempt = 0;
  Map<String, double>? _lastPoint;

  int? get activeOrderId => _orderId;
  bool get isRunning => _positions != null;

  /// Проверяет службу геолокации и разрешение. `null` — всё в порядке.
  Future<TrackingProblem?> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return TrackingProblem.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return TrackingProblem.permissionForever;
    }
    if (permission == LocationPermission.denied) {
      return TrackingProblem.permissionDenied;
    }
    return null;
  }

  /// Начать трекинг заказа. Повторный вызов с тем же заказом ничего не
  /// делает, с другим — переключает трекинг на него.
  Future<TrackingProblem?> start({required int orderId, required String token}) async {
    if (_orderId == orderId && isRunning) return null;
    await stop();

    final problem = await ensurePermission();
    if (problem != null) return problem;

    _orderId = orderId;
    _token = token;
    _connect();
    _positions = Geolocator.getPositionStream(locationSettings: _settings()).listen(
      (position) => _send({'lat': position.latitude, 'lon': position.longitude}),
      onError: (Object _) {},
    );
    return null;
  }

  Future<void> stop() async {
    await _positions?.cancel();
    _positions = null;
    _reconnect?.cancel();
    _reconnect = null;
    await _socket?.sink.close();
    _socket = null;
    _orderId = null;
    _token = null;
    _lastPoint = null;
    _attempt = 0;
  }

  LocationSettings _settings() {
    const accuracy = LocationAccuracy.high;
    const distance = 10; // метров между точками — курьер на скутере
    if (kIsWeb) {
      return const LocationSettings(accuracy: accuracy, distanceFilter: distance);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: accuracy,
          distanceFilter: distance,
          intervalDuration: const Duration(seconds: 5),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Идёт доставка',
            notificationText: 'Клиент видит, где вы. Остановится после доставки.',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: accuracy,
          distanceFilter: distance,
          activityType: ActivityType.automotiveNavigation,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      default:
        return const LocationSettings(accuracy: accuracy, distanceFilter: distance);
    }
  }

  Uri _wsUri(int orderId, String token) {
    final base = Uri.parse(ApiConfig.baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/courier-location/$orderId',
      queryParameters: {'token': token},
    );
  }

  void _connect() {
    final orderId = _orderId;
    final token = _token;
    if (orderId == null || token == null) return;
    try {
      final socket = WebSocketChannel.connect(_wsUri(orderId, token));
      _socket = socket;
      socket.ready.then((_) {
        _attempt = 0;
        final last = _lastPoint;
        if (last != null) socket.sink.add(jsonEncode(last));
      }).catchError((Object _) => _scheduleReconnect());
      socket.stream.listen(
        (_) {}, // сервер присылает эхо точек — курьеру они не нужны
        onDone: _scheduleReconnect,
        onError: (Object _) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_orderId == null || _reconnect != null) return;
    _socket = null;
    _attempt = (_attempt + 1).clamp(1, 6);
    final delay = Duration(seconds: const [1, 2, 5, 10, 20, 30][_attempt - 1]);
    _reconnect = Timer(delay, () {
      _reconnect = null;
      _connect();
    });
  }

  void _send(Map<String, double> point) {
    _lastPoint = point;
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.sink.add(jsonEncode(point));
    } catch (_) {
      _scheduleReconnect();
    }
  }
}

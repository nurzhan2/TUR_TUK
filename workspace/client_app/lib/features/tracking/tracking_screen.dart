import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../controllers/orders_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/order.dart';
import '../orders/widgets/courier_block.dart';
import '../orders/widgets/status_pill.dart';

/// Трекинг заказа: курьер едет по карте к отелю, карточка снизу показывает
/// статус и время в пути.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({required this.orderId, super.key});

  final int orderId;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with SingleTickerProviderStateMixin {
  final MapController _map = MapController();

  StreamSubscription<Order>? _track;

  /// Сдвиг курьера между тиками проигрывается анимацией, а не прыжком:
  /// тик раз в 4 секунды, и телепортация точки читается как сбой карты.
  /// 900 мс — заметно глазу и заканчивается задолго до следующего тика.
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addListener(_follow);

  Order? _order;
  LatLng? _from;
  LatLng? _to;

  /// Точка, в которой курьер был при первом тике. От неё считается
  /// прогресс: собственного «старта маршрута» в модели заказа нет, а
  /// брать координаты из демо-данных экрану нельзя — он не знает про демо.
  LatLng? _origin;

  bool _mapReady = false;
  bool _tilesFailed = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Пока не пришёл первый тик, показываем заказ из уже загруженного
    // списка: иначе экран открывается пустым, хотя все данные есть.
    _order = context.read<OrdersController>().byId(widget.orderId);
    _track = context.read<OrdersController>().track(widget.orderId).listen(
          _onTick,
          onError: (Object _) {
            if (mounted) setState(() => _failed = true);
          },
        );
  }

  @override
  void dispose() {
    // Подписка живёт ровно столько, сколько экран: без отмены следующий
    // тик прилетит в мёртвый виджет и уронит `setState`.
    _track?.cancel();
    _move
      ..removeListener(_follow)
      ..dispose();
    _map.dispose();
    super.dispose();
  }

  void _onTick(Order order) {
    final next = LatLng(order.courierLat, order.courierLng);
    final previous = _courier ?? next;
    setState(() {
      _order = order;
      _from = previous;
      _to = next;
      _origin ??= next;
    });
    _move.forward(from: 0);
    // Список заказов должен знать актуальный статус: вернувшись назад,
    // клиент не должен увидеть «собираем» у уже доставленного заказа.
    context.read<OrdersController>().applyTracked(order);
  }

  /// Камера идёт за курьером на каждом кадре анимации.
  void _follow() {
    final courier = _courier;
    if (!_mapReady || courier == null) return;
    _map.move(courier, _map.camera.zoom);
  }

  /// Текущее положение курьера с учётом проигрываемой анимации.
  LatLng? get _courier {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return null;
    final t = _move.value;
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  LatLng? get _hotel {
    final order = _order;
    if (order == null) return null;
    return LatLng(order.hotelLat, order.hotelLng);
  }

  /// Доля пройденного пути, 0..1.
  ///
  /// Расстояние считается прямо в градусах: на масштабе Кемера это честная
  /// пропорция, а точные метры для «осталось примерно N минут» всё равно
  /// не нужны.
  double get _progress {
    final origin = _origin;
    final hotel = _hotel;
    final courier = _courier;
    if (origin == null || hotel == null || courier == null) return 0;
    final full = _degrees(origin, hotel);
    if (full <= 0) return 1;
    final left = _degrees(courier, hotel);
    return (1 - left / full).clamp(0.0, 1.0);
  }

  static double _degrees(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  /// Двадцать минут на весь путь — столько едет курьер по Кемеру.
  int get _eta => math.max(1, ((1 - _progress) * 20).round());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final order = _order;

    if (_failed) return _errorScaffold(l10n);
    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.trackingTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap(order)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              child: Align(
                alignment: Alignment.topLeft,
                child: _RoundBackButton(onPressed: () => context.pop()),
              ),
            ),
          ),
          if (_tilesFailed)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSizes.pagePadding),
                  child: const _OfflineNote(),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _TrackingCard(
              order: order,
              eta: _eta,
              l10n: l10n,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorScaffold(AppLocalizations l10n) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackingTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined,
                  size: 56, color: AppColors.textMuted),
              const SizedBox(height: AppSizes.gap),
              Text(
                l10n.loadingError,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap(Order order) {
    final hotel = LatLng(order.hotelLat, order.hotelLng);
    final courier = _courier ?? LatLng(order.courierLat, order.courierLng);
    final center = LatLng(
      (hotel.latitude + courier.latitude) / 2,
      (hotel.longitude + courier.longitude) / 2,
    );

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        // Фон под тайлами — свой, а не жёлто-серый по умолчанию: если
        // тайлы не загрузятся (демо смотрят и без интернета), экран
        // останется частью приложения, а не станет чужим пятном.
        backgroundColor: AppColors.surface,
        onMapReady: () => _mapReady = true,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'ru.turtuk.client',
          // Сбойный тайл — не повод для исключения в консоль: помечаем
          // один раз и показываем подсказку, маркеры и линия остаются.
          errorTileCallback: (tile, error, stackTrace) {
            if (_tilesFailed || !mounted) return;
            _tilesFailed = true;
            // Колбэк прилетает во время отрисовки тайла, поэтому setState
            // откладываем до конца кадра.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          },
        ),
        AnimatedBuilder(
          animation: _move,
          builder: (context, child) => PolylineLayer(
            polylines: [
              Polyline(
                points: [_courier ?? courier, hotel],
                color: AppColors.accent.withValues(alpha: 0.7),
                strokeWidth: 4,
              ),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _move,
          builder: (context, child) => MarkerLayer(
            markers: [
              Marker(
                point: hotel,
                width: 44,
                height: 44,
                child: const _HotelMarker(),
              ),
              Marker(
                point: _courier ?? courier,
                width: 44,
                height: 44,
                child: const _CourierMarker(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourierMarker extends StatelessWidget {
  const _CourierMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.delivery_dining, color: Colors.white, size: 24),
    );
  }
}

class _HotelMarker extends StatelessWidget {
  const _HotelMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.location_on, color: AppColors.accent, size: 24),
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: const CircleBorder(),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// Подсказка про недоступные тайлы. Без неё пустая серая карта с двумя
/// точками выглядит недоделанной, а не «интернет не дошёл».
class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            // TODO l10n: строки нет в общем файле, новые ключи заводить нельзя
            'Карта недоступна офлайн',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Карточка поверх карты: статус, время в пути, курьер и связь с ним.
class _TrackingCard extends StatelessWidget {
  const _TrackingCard({
    required this.order,
    required this.eta,
    required this.l10n,
  });

  final Order order;
  final int eta;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arrived = order.status == OrderStatus.delivered;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding + 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill(status: order.status),
              const SizedBox(height: AppSizes.gap),
              Text(
                arrived ? l10n.trackingArrived : l10n.trackingCourierOnWay,
                style: theme.textTheme.headlineSmall,
              ),
              if (!arrived) ...[
                const SizedBox(height: 4),
                Text(l10n.trackingEta(eta), style: theme.textTheme.bodySmall),
              ],
              if (order.courierName != null) ...[
                const SizedBox(height: AppSizes.gap + 4),
                Row(
                  children: [
                    CourierAvatar(name: order.courierName!, size: 44),
                    const SizedBox(width: AppSizes.gap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.courierName!,
                              style: theme.textTheme.titleMedium),
                          Text(l10n.orderCourier,
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const CourierActions(),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

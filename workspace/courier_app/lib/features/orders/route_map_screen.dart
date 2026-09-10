import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'orders_controller.dart';

/// Карта маршрута: где курьер и куда ему ехать.
///
/// Прямая линия между точками, а не проложенный маршрут: прокладка требует
/// маршрутизатора (OSRM, Valhalla, платный Directions API), которого у
/// проекта нет. Линия честно показывает направление и расстояние, а
/// собственно вести должен навигатор телефона — кнопка внизу отдаёт ему
/// точку отеля.
class RouteMapScreen extends StatelessWidget {
  const RouteMapScreen({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final order = context.watch<OrdersController>().byId(orderId);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.orderNotFound)),
      );
    }

    final courier = LatLng(order.courierLat, order.courierLng);
    final hotel = LatLng(order.hotelLat, order.hotelLng);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeTitle)),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                // Рамка по двум точкам, а не центр с фиксированным зумом:
                // отели Кемера разбросаны на десяток километров, и один зум
                // на всех либо обрезал бы маршрут, либо показывал бы пол-Турции.
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds(courier, hotel),
                  padding: const EdgeInsets.all(48),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // Требование правил использования тайлов OSM: без него
                  // запросы вправе отклонить, и карта станет серой сеткой.
                  userAgentPackageName: 'com.turtuk.courier',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [courier, hotel],
                      color: AppColors.accent,
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: courier,
                      width: 40,
                      height: 40,
                      child: const _Pin(
                        icon: Icons.delivery_dining,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Marker(
                      point: hotel,
                      width: 40,
                      height: 40,
                      child: const _Pin(
                        icon: Icons.hotel,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                // Подпись OSM обязательна по лицензии ODbL — карта без неё
                // используется с нарушением условий.
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.hotel_outlined,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.orderAddress(order.hotelName, order.roomNumber),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.gap),
                  ElevatedButton.icon(
                    onPressed: () => _openNavigator(context, hotel),
                    icon: const Icon(Icons.navigation_outlined, size: 20),
                    label: Text(l10n.routeOpenInNavigator),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Схема `geo:` — штатный способ отдать точку любому установленному
  /// навигатору, а не привязываться к конкретному приложению. Своего
  /// навигатора у сервиса нет и быть не должно.
  Future<void> _openNavigator(BuildContext context, LatLng point) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context)!.routeLaunchFailed;
    final uri = Uri.parse('geo:${point.latitude},${point.longitude}');
    // На вебе и на десктопе обработчика `geo:` нет вовсе, поэтому отказ
    // здесь — обычный исход, а не авария: говорим о нём и остаёмся на карте.
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: color),
    );
  }
}

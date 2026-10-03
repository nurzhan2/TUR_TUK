import 'dart:convert';
import 'dart:typed_data';

import 'package:courier_app/core/network/api_client.dart';
import 'package:courier_app/features/orders/orders_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _order(String status) => {
      'id': 7,
      'user_id': 1,
      'courier_id': 2,
      'status': status,
      'total': 3500,
      'hotel_name': 'Sea View',
      'room_number': '101',
      'delivery_photo_url': null,
      'created_at': '2026-10-03T10:00:00Z',
      'items': <dynamic>[],
    };

void main() {
  test('подтверждение доставки: сначала снимок, потом статус', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/delivery-photo')) {
        expect(request.headers['content-type'], startsWith('multipart/form-data'));
        expect(request.headers['authorization'], 'Bearer t0k3n');
        return http.Response(jsonEncode(_order('delivering')), 200);
      }
      return http.Response(jsonEncode(_order('delivered')), 200);
    });
    final repo = ApiOrdersRepository(ApiClient(client: client, accessToken: 't0k3n'));

    final order = await repo.confirmDelivery(
      7,
      photo: DeliveryPhoto.bytes(Uint8List.fromList([0xFF, 0xD8, 0xFF])),
    );

    expect(calls, ['POST /orders/7/delivery-photo', 'PATCH /orders/7/status']);
    expect(order.status.name, 'delivered');
  });

  test('снимок не загрузился — заказ не становится доставленным', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      return http.Response.bytes(
        utf8.encode(jsonEncode({'detail': 'файл не похож на картинку'})),
        415,
      );
    });
    final repo = ApiOrdersRepository(ApiClient(client: client));

    await expectLater(
      repo.confirmDelivery(7, photo: DeliveryPhoto.bytes(Uint8List(3))),
      throwsA(isA<ApiException>()),
    );
    expect(calls, ['POST /orders/7/delivery-photo']);
  });

  test('без снимка с камеры (только ассет демо) боевой режим не закрывает заказ', () async {
    final client = MockClient((_) async => fail('запросов быть не должно'));
    final repo = ApiOrdersRepository(ApiClient(client: client));
    await expectLater(
      repo.confirmDelivery(7, photo: const DeliveryPhoto.asset('assets/box.jpg')),
      throwsA(isA<ApiException>()),
    );
  });
}

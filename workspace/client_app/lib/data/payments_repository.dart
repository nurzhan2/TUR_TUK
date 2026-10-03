import '../core/network/api_client.dart';

/// Оплата заказа через ЮKassa (боевой режим).
///
/// `POST /payments/create` возвращает `confirmation_url` — страницу оплаты
/// ЮKassa, где сразу открыт выбранный гостем способ (карта/СБП). Результат
/// оплаты приложение не «узнаёт» само: ЮKassa присылает вебхук на сервер,
/// сервер перепроверяет статус и помечает заказ оплаченным. Повторный вызов
/// для того же заказа вернёт тот же неоплаченный платёж, а не создаст второй.
class PaymentsRepository {
  PaymentsRepository(this._api);

  final ApiClient _api;

  Future<String> confirmationUrl(int orderId) async {
    final body = await _api.post('/payments/create', body: {'order_id': orderId})
        as Map<String, dynamic>;
    final url = body['confirmation_url'] as String?;
    if (url == null || url.isEmpty) {
      throw ApiException(502, 'платёжная система не вернула ссылку на оплату');
    }
    return url;
  }
}

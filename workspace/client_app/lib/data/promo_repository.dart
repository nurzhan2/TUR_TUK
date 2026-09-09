import '../core/demo/demo_data.dart';
import '../core/network/api_client.dart';
import '../models/promo_result.dart';
import 'catalog_repository.dart' show kDemoLatency;

abstract class PromoRepository {
  Future<PromoResult> validate(String code, double cartTotal);
}

class DemoPromoRepository implements PromoRepository {
  const DemoPromoRepository();

  @override
  Future<PromoResult> validate(String code, double cartTotal) async {
    await Future<void>.delayed(kDemoLatency);
    // Регистр не важен: человек набирает промокод с рекламной листовки,
    // и «kemer10» с маленькой буквы — это тот же промокод.
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      return PromoResult.invalid(code, 'Введите промокод', cartTotal);
    }

    for (final promo in DemoData.promos()) {
      if (promo.code != normalized) continue;
      if (promo.expired) {
        return PromoResult.invalid(
          normalized,
          'Срок действия промокода истёк',
          cartTotal,
        );
      }
      final discount = promo.discountFor(cartTotal);
      return PromoResult(
        valid: true,
        code: normalized,
        discount: discount,
        totalAfterDiscount: cartTotal - discount,
      );
    }
    return PromoResult.invalid(normalized, 'Промокод не найден', cartTotal);
  }
}

class ApiPromoRepository implements PromoRepository {
  ApiPromoRepository(this._api);

  final ApiClient _api;

  @override
  Future<PromoResult> validate(String code, double cartTotal) async {
    try {
      final body = await _api.post(
        '/promo/validate',
        body: {'code': code.trim(), 'cart_total': cartTotal},
      ) as Map<String, dynamic>;
      return PromoResult.fromJson(body);
    } on ApiException catch (error) {
      // Отказ бэкенда — это ЗНАЧЕНИЕ, а не авария: «промокод просрочен»
      // экран показывает подписью под полем. Пробрасывать сюда исключение
      // значило бы разбирать его текст в виджете.
      return PromoResult.invalid(code.trim(), error.detail, cartTotal);
    }
  }
}

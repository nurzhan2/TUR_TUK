/// Ответ на проверку промокода.
///
/// Неудача — это ЗНАЧЕНИЕ, а не исключение: «промокод просрочен» экран
/// показывает подписью под полем, и гонять такой ответ через try/catch
/// значило бы разбирать текст ошибки на экране.
class PromoResult {
  const PromoResult({
    required this.valid,
    required this.code,
    required this.discount,
    required this.totalAfterDiscount,
    this.error,
  });

  final bool valid;
  final String code;
  final double discount;
  final double totalAfterDiscount;
  final String? error;

  factory PromoResult.invalid(String code, String error, double cartTotal) {
    return PromoResult(
      valid: false,
      code: code,
      discount: 0,
      totalAfterDiscount: cartTotal,
      error: error,
    );
  }

  factory PromoResult.fromJson(Map<String, dynamic> json) => PromoResult(
        valid: true,
        code: json['code'] as String,
        discount: (json['discount_amount'] as num).toDouble(),
        totalAfterDiscount: (json['total_after_discount'] as num).toDouble(),
      );
}

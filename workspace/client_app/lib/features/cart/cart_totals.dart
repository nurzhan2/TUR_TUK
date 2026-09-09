/// Арифметика воронки покупки: корзина и чекаут считают итог ОДНИМ кодом.
///
/// Заказчица проходит воронку насквозь и сверяет цифры на каждом шаге, а
/// «Итого» в корзине и «К оплате» на чекауте — это одна и та же сумма,
/// показанная дважды. Два независимых расчёта разошлись бы на первой же
/// правке порога бесплатной доставки, и разошлись бы молча.
class CartTotals {
  const CartTotals({required this.subtotal, this.discount = 0});

  /// Пороги демо (`docs/prompts/_common.md`): минимальный заказ 3000 ₽,
  /// доставка 300 ₽, бесплатно от 5000 ₽. Константы продублированы здесь,
  /// а не взяты из `core/demo/demo_data.dart`, намеренно: выше уровня `Di`
  /// экраны о существовании демо-режима не знают.
  static const double minOrder = 3000;
  static const double deliveryFee = 300;
  static const double freeDeliveryFrom = 5000;

  /// Сумма товаров без доставки и скидки.
  final double subtotal;

  /// Скидка по промокоду. В корзине промокода ещё нет, там всегда 0.
  final double discount;

  bool get isDeliveryFree => subtotal >= freeDeliveryFrom;

  double get delivery => isDeliveryFree ? 0 : deliveryFee;

  double get total => subtotal - discount + delivery;

  bool get belowMinOrder => subtotal < minOrder;

  /// Сколько не хватает до минимального заказа — это число человек видит
  /// на плашке и добирает корзину до него.
  double get missingToMinOrder =>
      belowMinOrder ? minOrder - subtotal : 0;

  /// Заполненность прогресс-бара минималки, 0..1.
  double get minOrderProgress =>
      minOrder == 0 ? 1 : (subtotal / minOrder).clamp(0.0, 1.0);
}

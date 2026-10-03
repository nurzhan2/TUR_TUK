import '../../core/content/app_content.dart';

/// Арифметика воронки покупки: корзина и чекаут считают итог ОДНИМ кодом.
///
/// Заказчица проходит воронку насквозь и сверяет цифры на каждом шаге, а
/// «Итого» в корзине и «К оплате» на чекауте — это одна и та же сумма,
/// показанная дважды. Два независимых расчёта разошлись бы на первой же
/// правке порога бесплатной доставки, и разошлись бы молча.
class CartTotals {
  const CartTotals({required this.subtotal, this.discount = 0});

  /// Пороги приходят из настроек (`content/settings.json`): их правит
  /// заказчица, а не разработчик. Экраны при этом по-прежнему ничего не знают
  /// о демо-режиме — контент и режим работы это разные вещи.
  static double get minOrder => AppContent.instance.delivery.minOrderTotal;
  static double get deliveryFee => AppContent.instance.delivery.deliveryFee;
  static double get freeDeliveryFrom =>
      AppContent.instance.delivery.freeDeliveryFrom;

  /// Сумма товаров без доставки и скидки.
  final double subtotal;

  /// Скидка по промокоду. В корзине промокода ещё нет, там всегда 0.
  final double discount;

  /// Формула одна с сервером (`delivery_fee_for`): порог 0 — бесплатной
  /// доставки нет, иначе по сумме товаров ДО скидки.
  bool get isDeliveryFree => freeDeliveryFrom > 0 && subtotal >= freeDeliveryFrom;

  /// Сколько добрать до бесплатной доставки; 0 — уже бесплатно или порога нет.
  double get missingToFreeDelivery =>
      freeDeliveryFrom > 0 && !isDeliveryFree ? freeDeliveryFrom - subtotal : 0;

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

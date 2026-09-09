// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get retry => 'Повторить';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get close => 'Закрыть';

  @override
  String get loadingError =>
      'Не удалось загрузить. Проверьте соединение и попробуйте ещё раз.';

  @override
  String get comingSoon => 'Скоро появится';

  @override
  String get catalogTitle => 'Каталог';

  @override
  String get searchHint => 'Поиск товаров';

  @override
  String get categoriesAll => 'Все';

  @override
  String get addToCart => 'В корзину';

  @override
  String get outOfStock => 'Нет в наличии';

  @override
  String get catalogEmpty => 'Ничего не нашлось. Попробуйте другой запрос.';

  @override
  String get popular => 'Популярное';

  @override
  String get productToCart => 'Добавить в корзину';

  @override
  String get productInCart => 'В корзине';

  @override
  String get productDescriptionTitle => 'Описание';

  @override
  String get productSimilar => 'Похожие товары';

  @override
  String get cartTitle => 'Корзина';

  @override
  String get cartEmpty =>
      'Корзина пуста. Загляните в каталог — привезём в отель за час.';

  @override
  String get cartTotal => 'Итого';

  @override
  String get cartCheckout => 'Оформить заказ';

  @override
  String cartMinOrder(String amount) {
    return 'Минимальная сумма заказа — $amount';
  }

  @override
  String get cartClear => 'Очистить корзину';

  @override
  String cartItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count товара',
      many: '$count товаров',
      few: '$count товара',
      one: '$count товар',
    );
    return '$_temp0';
  }

  @override
  String get checkoutTitle => 'Оформление заказа';

  @override
  String get checkoutHotel => 'Отель';

  @override
  String get checkoutRoom => 'Номер комнаты';

  @override
  String get checkoutComment => 'Комментарий курьеру';

  @override
  String get checkoutPromo => 'Промокод';

  @override
  String get checkoutPromoApply => 'Применить';

  @override
  String get checkoutPromoApplied => 'Промокод применён';

  @override
  String get checkoutPromoInvalid => 'Промокод не подошёл';

  @override
  String get checkoutSubtotal => 'Товары';

  @override
  String get checkoutDiscount => 'Скидка';

  @override
  String get checkoutDelivery => 'Доставка';

  @override
  String get checkoutTotal => 'К оплате';

  @override
  String get checkoutPay => 'Оплатить';

  @override
  String get checkoutPaymentCard => 'Банковская карта';

  @override
  String get checkoutPaymentSbp => 'СБП';

  @override
  String get checkoutSuccess => 'Заказ оформлен';

  @override
  String get checkoutSuccessSub =>
      'Курьер соберёт заказ и привезёт его на рецепцию вашего отеля.';

  @override
  String get checkoutMinOrderError =>
      'Добавьте товаров — минимальная сумма заказа не набрана';

  @override
  String get ordersTitle => 'Мои заказы';

  @override
  String get ordersEmpty =>
      'Заказов пока нет. Первый можно собрать в каталоге.';

  @override
  String orderNumber(int id) {
    return 'Заказ №$id';
  }

  @override
  String get orderRepeat => 'Повторить заказ';

  @override
  String get orderDetails => 'Подробнее';

  @override
  String get orderTrack => 'Отследить';

  @override
  String get orderDeliveryTo => 'Доставка в';

  @override
  String get orderCourier => 'Курьер';

  @override
  String get orderPlacedAt => 'Оформлен';

  @override
  String get orderItems => 'Состав заказа';

  @override
  String get orderDeliveryPhoto => 'Фото доставки';

  @override
  String get orderStatusCreated => 'Создан';

  @override
  String get orderStatusAccepted => 'Принят';

  @override
  String get orderStatusAssembling => 'Собираем';

  @override
  String get orderStatusDelivering => 'В пути';

  @override
  String get orderStatusDelivered => 'Доставлен';

  @override
  String get orderStatusCancelled => 'Отменён';

  @override
  String get trackingTitle => 'Отслеживание';

  @override
  String trackingEta(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Курьер приедет через $minutes минуты',
      many: 'Курьер приедет через $minutes минут',
      few: 'Курьер приедет через $minutes минуты',
      one: 'Курьер приедет через $minutes минуту',
    );
    return '$_temp0';
  }

  @override
  String get trackingCourierOnWay => 'Курьер в пути';

  @override
  String get trackingArrived => 'Курьер на месте';

  @override
  String get chatTitle => 'Поддержка';

  @override
  String get chatHint => 'Напишите сообщение';

  @override
  String get chatSend => 'Отправить';

  @override
  String get chatBotLabel => 'Бот';

  @override
  String get chatOperatorLabel => 'Оператор';

  @override
  String get authTitle => 'Добро пожаловать в TUR TUK';

  @override
  String get authSubtitle =>
      'Доставим сувениры, косметику и продукты прямо в отель';

  @override
  String get authPhone => 'Номер телефона';

  @override
  String get authGetCode => 'Получить код';

  @override
  String get authCode => 'Код из СМС';

  @override
  String get authConfirm => 'Подтвердить';

  @override
  String authResend(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Отправить код повторно через $seconds секунды',
      many: 'Отправить код повторно через $seconds секунд',
      few: 'Отправить код повторно через $seconds секунды',
      one: 'Отправить код повторно через $seconds секунду',
    );
    return '$_temp0';
  }

  @override
  String get authName => 'Имя';

  @override
  String get authDob => 'Дата рождения';

  @override
  String get authHotel => 'Отель';

  @override
  String get authRoom => 'Номер комнаты';

  @override
  String get authRegisterTitle => 'Немного о вас';

  @override
  String get authContinue => 'Продолжить';

  @override
  String get authInvalidCode => 'Неверный код';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileLanguage => 'Язык приложения';

  @override
  String get profileRussian => 'Русский';

  @override
  String get profileEnglish => 'English';

  @override
  String get profileTurkish => 'Türkçe';

  @override
  String get profileMyOrders => 'Мои заказы';

  @override
  String get profileSupport => 'Поддержка';

  @override
  String get profileHotel => 'Отель';

  @override
  String get profileRoom => 'Номер комнаты';

  @override
  String get profileLogout => 'Выйти';

  @override
  String get profileEdit => 'Редактировать';
}

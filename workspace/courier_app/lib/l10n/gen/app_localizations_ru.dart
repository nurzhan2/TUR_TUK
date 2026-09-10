// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'TUR TUK Курьер';

  @override
  String get authTitle => 'Вход для курьеров';

  @override
  String get phoneLabel => 'Номер телефона';

  @override
  String get phoneHint => '+90 5xx xxx xx xx';

  @override
  String get sendCodeButton => 'Отправить код';

  @override
  String get codeLabel => 'Код из SMS';

  @override
  String get codeHint => '0000';

  @override
  String get verifyCodeButton => 'Подтвердить';

  @override
  String get resendCodeButton => 'Отправить код ещё раз';

  @override
  String get changePhoneButton => 'Изменить номер';

  @override
  String get authGenericError =>
      'Не удалось выполнить вход. Попробуйте ещё раз.';

  @override
  String get authInvalidCode => 'Неверный или истёкший код';

  @override
  String get authPhoneRequired => 'Введите номер телефона';

  @override
  String get authCodeRequired => 'Введите код из SMS';

  @override
  String get ordersTitle => 'Заказы';

  @override
  String get ordersEmpty => 'Пока нет заказов';

  @override
  String get ordersLoadError => 'Не удалось загрузить заказы';

  @override
  String get ordersRetryButton => 'Повторить';

  @override
  String orderNumber(int id) {
    return 'Заказ №$id';
  }

  @override
  String get sectionNew => 'Новые';

  @override
  String get sectionInProgress => 'В работе';

  @override
  String get sectionDone => 'Выполненные';

  @override
  String get sectionEmpty => 'Здесь пока пусто';

  @override
  String orderAddress(String hotel, String room) {
    return '$hotel, номер $room';
  }

  @override
  String orderItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count позиции',
      many: '$count позиций',
      few: '$count позиции',
      one: '$count позиция',
    );
    return '$_temp0';
  }

  @override
  String get orderNotFound => 'Заказ не найден';

  @override
  String get orderItemsTitle => 'Состав заказа';

  @override
  String get orderItemsUnavailable => 'Состав заказа недоступен';

  @override
  String get orderClientTitle => 'Клиент';

  @override
  String get orderCall => 'Позвонить';

  @override
  String get orderHotel => 'Отель';

  @override
  String get orderRoom => 'Номер комнаты';

  @override
  String get orderTotal => 'Сумма заказа';

  @override
  String orderCreatedAt(String time) {
    return 'Оформлен в $time';
  }

  @override
  String get orderStatusCreated => 'новый';

  @override
  String get orderStatusAccepted => 'принят';

  @override
  String get orderStatusAssembling => 'на сборке';

  @override
  String get orderStatusDelivering => 'в пути';

  @override
  String get orderStatusDelivered => 'доставлен';

  @override
  String get orderStatusCancelled => 'отменён';

  @override
  String get actionAccept => 'Принять';

  @override
  String get actionReject => 'Отклонить';

  @override
  String get actionStartAssembly => 'Начать сборку';

  @override
  String get actionDepart => 'Выехал';

  @override
  String get actionDelivered => 'Доставлен';

  @override
  String get actionRoute => 'Маршрут';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get rejectConfirmTitle => 'Отклонить заказ?';

  @override
  String get rejectConfirmText =>
      'Заказ вернётся диспетчеру. Отменить это действие из приложения нельзя.';

  @override
  String get deliveryTitle => 'Подтверждение доставки';

  @override
  String get deliveryHint =>
      'Снимите коробку на рецепции — снимок подтверждает доставку.';

  @override
  String get deliveryTakePhoto => 'Сфотографировать коробку';

  @override
  String get deliveryRetakePhoto => 'Сделать другой снимок';

  @override
  String get deliveryConfirm => 'Подтвердить доставку';

  @override
  String get deliveryDone => 'Заказ доставлен';

  @override
  String get deliveryPhotoTitle => 'Фото доставки';

  @override
  String get routeTitle => 'Маршрут';

  @override
  String get routeCourier => 'Курьер';

  @override
  String get routeOpenInNavigator => 'Открыть в навигаторе';

  @override
  String get routeLaunchFailed => 'Не удалось открыть навигатор';

  @override
  String get logoutButton => 'Выйти';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageEn => 'English';

  @override
  String get languageTr => 'Türkçe';
}

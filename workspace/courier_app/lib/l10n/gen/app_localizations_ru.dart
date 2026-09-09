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
  String get ordersTitle => 'Новые заказы';

  @override
  String get ordersEmpty => 'Пока нет новых заказов';

  @override
  String get ordersLoadError => 'Не удалось загрузить заказы';

  @override
  String get ordersRetryButton => 'Повторить';

  @override
  String orderNumber(int id) {
    return 'Заказ №$id';
  }

  @override
  String get orderStatusCreated => 'принят';

  @override
  String get orderStatusAccepted => 'принят курьером';

  @override
  String get orderStatusAssembling => 'на сборке';

  @override
  String get orderStatusDelivering => 'доставляется';

  @override
  String get orderStatusDelivered => 'доставлен';

  @override
  String get orderStatusCancelled => 'отменён';

  @override
  String get logoutButton => 'Выйти';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageEn => 'English';

  @override
  String get languageTr => 'Türkçe';
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @loadingError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить. Проверьте соединение и попробуйте ещё раз.'**
  String get loadingError;

  /// No description provided for @comingSoon.
  ///
  /// In ru, this message translates to:
  /// **'Скоро появится'**
  String get comingSoon;

  /// No description provided for @catalogTitle.
  ///
  /// In ru, this message translates to:
  /// **'Каталог'**
  String get catalogTitle;

  /// No description provided for @searchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск товаров'**
  String get searchHint;

  /// No description provided for @categoriesAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get categoriesAll;

  /// No description provided for @addToCart.
  ///
  /// In ru, this message translates to:
  /// **'В корзину'**
  String get addToCart;

  /// No description provided for @outOfStock.
  ///
  /// In ru, this message translates to:
  /// **'Нет в наличии'**
  String get outOfStock;

  /// No description provided for @catalogEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не нашлось. Попробуйте другой запрос.'**
  String get catalogEmpty;

  /// No description provided for @popular.
  ///
  /// In ru, this message translates to:
  /// **'Популярное'**
  String get popular;

  /// No description provided for @productToCart.
  ///
  /// In ru, this message translates to:
  /// **'Добавить в корзину'**
  String get productToCart;

  /// No description provided for @productInCart.
  ///
  /// In ru, this message translates to:
  /// **'В корзине'**
  String get productInCart;

  /// No description provided for @productDescriptionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get productDescriptionTitle;

  /// No description provided for @productSimilar.
  ///
  /// In ru, this message translates to:
  /// **'Похожие товары'**
  String get productSimilar;

  /// No description provided for @cartTitle.
  ///
  /// In ru, this message translates to:
  /// **'Корзина'**
  String get cartTitle;

  /// No description provided for @cartEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Корзина пуста. Загляните в каталог — привезём в отель за час.'**
  String get cartEmpty;

  /// No description provided for @cartTotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого'**
  String get cartTotal;

  /// No description provided for @cartCheckout.
  ///
  /// In ru, this message translates to:
  /// **'Оформить заказ'**
  String get cartCheckout;

  /// No description provided for @cartMinOrder.
  ///
  /// In ru, this message translates to:
  /// **'Минимальная сумма заказа — {amount}'**
  String cartMinOrder(String amount);

  /// No description provided for @cartClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить корзину'**
  String get cartClear;

  /// No description provided for @cartItems.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} товар} few{{count} товара} many{{count} товаров} other{{count} товара}}'**
  String cartItems(int count);

  /// No description provided for @checkoutTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оформление заказа'**
  String get checkoutTitle;

  /// No description provided for @checkoutHotel.
  ///
  /// In ru, this message translates to:
  /// **'Отель'**
  String get checkoutHotel;

  /// No description provided for @checkoutRoom.
  ///
  /// In ru, this message translates to:
  /// **'Номер комнаты'**
  String get checkoutRoom;

  /// No description provided for @checkoutComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий курьеру'**
  String get checkoutComment;

  /// No description provided for @checkoutPromo.
  ///
  /// In ru, this message translates to:
  /// **'Промокод'**
  String get checkoutPromo;

  /// No description provided for @checkoutPromoApply.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get checkoutPromoApply;

  /// No description provided for @checkoutPromoApplied.
  ///
  /// In ru, this message translates to:
  /// **'Промокод применён'**
  String get checkoutPromoApplied;

  /// No description provided for @checkoutPromoInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Промокод не подошёл'**
  String get checkoutPromoInvalid;

  /// No description provided for @checkoutSubtotal.
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get checkoutSubtotal;

  /// No description provided for @checkoutDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Скидка'**
  String get checkoutDiscount;

  /// No description provided for @checkoutDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставка'**
  String get checkoutDelivery;

  /// No description provided for @checkoutTotal.
  ///
  /// In ru, this message translates to:
  /// **'К оплате'**
  String get checkoutTotal;

  /// No description provided for @checkoutPay.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить'**
  String get checkoutPay;

  /// No description provided for @checkoutPaymentCard.
  ///
  /// In ru, this message translates to:
  /// **'Банковская карта'**
  String get checkoutPaymentCard;

  /// No description provided for @checkoutPaymentSbp.
  ///
  /// In ru, this message translates to:
  /// **'СБП'**
  String get checkoutPaymentSbp;

  /// No description provided for @checkoutSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Заказ оформлен'**
  String get checkoutSuccess;

  /// No description provided for @checkoutSuccessSub.
  ///
  /// In ru, this message translates to:
  /// **'Курьер соберёт заказ и привезёт его на рецепцию вашего отеля.'**
  String get checkoutSuccessSub;

  /// No description provided for @checkoutMinOrderError.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте товаров — минимальная сумма заказа не набрана'**
  String get checkoutMinOrderError;

  /// No description provided for @ordersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мои заказы'**
  String get ordersTitle;

  /// No description provided for @ordersEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Заказов пока нет. Первый можно собрать в каталоге.'**
  String get ordersEmpty;

  /// No description provided for @orderNumber.
  ///
  /// In ru, this message translates to:
  /// **'Заказ №{id}'**
  String orderNumber(int id);

  /// No description provided for @orderRepeat.
  ///
  /// In ru, this message translates to:
  /// **'Повторить заказ'**
  String get orderRepeat;

  /// No description provided for @orderDetails.
  ///
  /// In ru, this message translates to:
  /// **'Подробнее'**
  String get orderDetails;

  /// No description provided for @orderTrack.
  ///
  /// In ru, this message translates to:
  /// **'Отследить'**
  String get orderTrack;

  /// No description provided for @orderDeliveryTo.
  ///
  /// In ru, this message translates to:
  /// **'Доставка в'**
  String get orderDeliveryTo;

  /// No description provided for @orderCourier.
  ///
  /// In ru, this message translates to:
  /// **'Курьер'**
  String get orderCourier;

  /// No description provided for @orderPlacedAt.
  ///
  /// In ru, this message translates to:
  /// **'Оформлен'**
  String get orderPlacedAt;

  /// No description provided for @orderItems.
  ///
  /// In ru, this message translates to:
  /// **'Состав заказа'**
  String get orderItems;

  /// No description provided for @orderDeliveryPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Фото доставки'**
  String get orderDeliveryPhoto;

  /// No description provided for @orderStatusCreated.
  ///
  /// In ru, this message translates to:
  /// **'Создан'**
  String get orderStatusCreated;

  /// No description provided for @orderStatusAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Принят'**
  String get orderStatusAccepted;

  /// No description provided for @orderStatusAssembling.
  ///
  /// In ru, this message translates to:
  /// **'Собираем'**
  String get orderStatusAssembling;

  /// No description provided for @orderStatusDelivering.
  ///
  /// In ru, this message translates to:
  /// **'В пути'**
  String get orderStatusDelivering;

  /// No description provided for @orderStatusDelivered.
  ///
  /// In ru, this message translates to:
  /// **'Доставлен'**
  String get orderStatusDelivered;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменён'**
  String get orderStatusCancelled;

  /// No description provided for @trackingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отслеживание'**
  String get trackingTitle;

  /// No description provided for @trackingEta.
  ///
  /// In ru, this message translates to:
  /// **'{minutes, plural, one{Курьер приедет через {minutes} минуту} few{Курьер приедет через {minutes} минуты} many{Курьер приедет через {minutes} минут} other{Курьер приедет через {minutes} минуты}}'**
  String trackingEta(int minutes);

  /// No description provided for @trackingCourierOnWay.
  ///
  /// In ru, this message translates to:
  /// **'Курьер в пути'**
  String get trackingCourierOnWay;

  /// No description provided for @trackingArrived.
  ///
  /// In ru, this message translates to:
  /// **'Курьер на месте'**
  String get trackingArrived;

  /// No description provided for @chatTitle.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка'**
  String get chatTitle;

  /// No description provided for @chatHint.
  ///
  /// In ru, this message translates to:
  /// **'Напишите сообщение'**
  String get chatHint;

  /// No description provided for @chatSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get chatSend;

  /// No description provided for @chatBotLabel.
  ///
  /// In ru, this message translates to:
  /// **'Бот'**
  String get chatBotLabel;

  /// No description provided for @chatOperatorLabel.
  ///
  /// In ru, this message translates to:
  /// **'Оператор'**
  String get chatOperatorLabel;

  /// No description provided for @authTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добро пожаловать в TUR TUK'**
  String get authTitle;

  /// No description provided for @authSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Доставим сувениры, косметику и продукты прямо в отель'**
  String get authSubtitle;

  /// No description provided for @authPhone.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона'**
  String get authPhone;

  /// No description provided for @authGetCode.
  ///
  /// In ru, this message translates to:
  /// **'Получить код'**
  String get authGetCode;

  /// No description provided for @authCode.
  ///
  /// In ru, this message translates to:
  /// **'Код из СМС'**
  String get authCode;

  /// No description provided for @authConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get authConfirm;

  /// No description provided for @authResend.
  ///
  /// In ru, this message translates to:
  /// **'{seconds, plural, one{Отправить код повторно через {seconds} секунду} few{Отправить код повторно через {seconds} секунды} many{Отправить код повторно через {seconds} секунд} other{Отправить код повторно через {seconds} секунды}}'**
  String authResend(int seconds);

  /// No description provided for @authName.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get authName;

  /// No description provided for @authDob.
  ///
  /// In ru, this message translates to:
  /// **'Дата рождения'**
  String get authDob;

  /// No description provided for @authHotel.
  ///
  /// In ru, this message translates to:
  /// **'Отель'**
  String get authHotel;

  /// No description provided for @authRoom.
  ///
  /// In ru, this message translates to:
  /// **'Номер комнаты'**
  String get authRoom;

  /// No description provided for @authRegisterTitle.
  ///
  /// In ru, this message translates to:
  /// **'Немного о вас'**
  String get authRegisterTitle;

  /// No description provided for @authContinue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get authContinue;

  /// No description provided for @authInvalidCode.
  ///
  /// In ru, this message translates to:
  /// **'Неверный код'**
  String get authInvalidCode;

  /// No description provided for @profileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profileTitle;

  /// No description provided for @profileLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык приложения'**
  String get profileLanguage;

  /// No description provided for @profileRussian.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get profileRussian;

  /// No description provided for @profileEnglish.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get profileEnglish;

  /// No description provided for @profileTurkish.
  ///
  /// In ru, this message translates to:
  /// **'Türkçe'**
  String get profileTurkish;

  /// No description provided for @profileMyOrders.
  ///
  /// In ru, this message translates to:
  /// **'Мои заказы'**
  String get profileMyOrders;

  /// No description provided for @profileSupport.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка'**
  String get profileSupport;

  /// No description provided for @profileHotel.
  ///
  /// In ru, this message translates to:
  /// **'Отель'**
  String get profileHotel;

  /// No description provided for @profileRoom.
  ///
  /// In ru, this message translates to:
  /// **'Номер комнаты'**
  String get profileRoom;

  /// No description provided for @profileLogout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get profileLogout;

  /// No description provided for @profileEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get profileEdit;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

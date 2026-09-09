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

  /// Название приложения в списке приложений устройства
  ///
  /// In ru, this message translates to:
  /// **'TUR TUK Курьер'**
  String get appTitle;

  /// Заголовок экрана авторизации
  ///
  /// In ru, this message translates to:
  /// **'Вход для курьеров'**
  String get authTitle;

  /// No description provided for @phoneLabel.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона'**
  String get phoneLabel;

  /// No description provided for @phoneHint.
  ///
  /// In ru, this message translates to:
  /// **'+90 5xx xxx xx xx'**
  String get phoneHint;

  /// No description provided for @sendCodeButton.
  ///
  /// In ru, this message translates to:
  /// **'Отправить код'**
  String get sendCodeButton;

  /// No description provided for @codeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код из SMS'**
  String get codeLabel;

  /// No description provided for @codeHint.
  ///
  /// In ru, this message translates to:
  /// **'0000'**
  String get codeHint;

  /// No description provided for @verifyCodeButton.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get verifyCodeButton;

  /// No description provided for @resendCodeButton.
  ///
  /// In ru, this message translates to:
  /// **'Отправить код ещё раз'**
  String get resendCodeButton;

  /// No description provided for @changePhoneButton.
  ///
  /// In ru, this message translates to:
  /// **'Изменить номер'**
  String get changePhoneButton;

  /// No description provided for @authGenericError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить вход. Попробуйте ещё раз.'**
  String get authGenericError;

  /// No description provided for @authInvalidCode.
  ///
  /// In ru, this message translates to:
  /// **'Неверный или истёкший код'**
  String get authInvalidCode;

  /// No description provided for @authPhoneRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите номер телефона'**
  String get authPhoneRequired;

  /// No description provided for @authCodeRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите код из SMS'**
  String get authCodeRequired;

  /// Заголовок главного экрана курьера — список новых заказов
  ///
  /// In ru, this message translates to:
  /// **'Новые заказы'**
  String get ordersTitle;

  /// No description provided for @ordersEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет новых заказов'**
  String get ordersEmpty;

  /// No description provided for @ordersLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить заказы'**
  String get ordersLoadError;

  /// No description provided for @ordersRetryButton.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get ordersRetryButton;

  /// Номер заказа в списке
  ///
  /// In ru, this message translates to:
  /// **'Заказ №{id}'**
  String orderNumber(int id);

  /// No description provided for @orderStatusCreated.
  ///
  /// In ru, this message translates to:
  /// **'принят'**
  String get orderStatusCreated;

  /// No description provided for @orderStatusAccepted.
  ///
  /// In ru, this message translates to:
  /// **'принят курьером'**
  String get orderStatusAccepted;

  /// No description provided for @orderStatusAssembling.
  ///
  /// In ru, this message translates to:
  /// **'на сборке'**
  String get orderStatusAssembling;

  /// No description provided for @orderStatusDelivering.
  ///
  /// In ru, this message translates to:
  /// **'доставляется'**
  String get orderStatusDelivering;

  /// No description provided for @orderStatusDelivered.
  ///
  /// In ru, this message translates to:
  /// **'доставлен'**
  String get orderStatusDelivered;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In ru, this message translates to:
  /// **'отменён'**
  String get orderStatusCancelled;

  /// No description provided for @logoutButton.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get logoutButton;

  /// No description provided for @languageRu.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get languageRu;

  /// No description provided for @languageEn.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageTr.
  ///
  /// In ru, this message translates to:
  /// **'Türkçe'**
  String get languageTr;
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

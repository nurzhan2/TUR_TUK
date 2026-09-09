// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TUR TUK Courier';

  @override
  String get authTitle => 'Courier sign in';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get phoneHint => '+90 5xx xxx xx xx';

  @override
  String get sendCodeButton => 'Send code';

  @override
  String get codeLabel => 'SMS code';

  @override
  String get codeHint => '0000';

  @override
  String get verifyCodeButton => 'Confirm';

  @override
  String get resendCodeButton => 'Resend code';

  @override
  String get changePhoneButton => 'Change number';

  @override
  String get authGenericError => 'Sign in failed. Please try again.';

  @override
  String get authInvalidCode => 'Invalid or expired code';

  @override
  String get authPhoneRequired => 'Enter your phone number';

  @override
  String get authCodeRequired => 'Enter the SMS code';

  @override
  String get ordersTitle => 'New orders';

  @override
  String get ordersEmpty => 'No new orders yet';

  @override
  String get ordersLoadError => 'Failed to load orders';

  @override
  String get ordersRetryButton => 'Retry';

  @override
  String orderNumber(int id) {
    return 'Order #$id';
  }

  @override
  String get orderStatusCreated => 'created';

  @override
  String get orderStatusAccepted => 'accepted';

  @override
  String get orderStatusAssembling => 'assembling';

  @override
  String get orderStatusDelivering => 'delivering';

  @override
  String get orderStatusDelivered => 'delivered';

  @override
  String get orderStatusCancelled => 'cancelled';

  @override
  String get logoutButton => 'Log out';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageEn => 'English';

  @override
  String get languageTr => 'Türkçe';
}

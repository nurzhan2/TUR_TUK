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
  String get resendCodeButton => 'Send the code again';

  @override
  String get changePhoneButton => 'Change number';

  @override
  String get authGenericError => 'Sign in failed. Please try again.';

  @override
  String get authInvalidCode => 'Wrong or expired code';

  @override
  String get authPhoneRequired => 'Enter your phone number';

  @override
  String get authCodeRequired => 'Enter the code from SMS';

  @override
  String get ordersTitle => 'Orders';

  @override
  String get ordersEmpty => 'No orders yet';

  @override
  String get ordersLoadError => 'Could not load orders';

  @override
  String get ordersRetryButton => 'Retry';

  @override
  String orderNumber(int id) {
    return 'Order #$id';
  }

  @override
  String get sectionNew => 'New';

  @override
  String get sectionInProgress => 'In progress';

  @override
  String get sectionDone => 'Completed';

  @override
  String get sectionEmpty => 'Nothing here yet';

  @override
  String orderAddress(String hotel, String room) {
    return '$hotel, room $room';
  }

  @override
  String orderItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get orderNotFound => 'Order not found';

  @override
  String get orderItemsTitle => 'Items';

  @override
  String get orderItemsUnavailable => 'Item list is unavailable';

  @override
  String get orderClientTitle => 'Client';

  @override
  String get orderCall => 'Call';

  @override
  String get orderHotel => 'Hotel';

  @override
  String get orderRoom => 'Room number';

  @override
  String get orderTotal => 'Order total';

  @override
  String orderCreatedAt(String time) {
    return 'Placed at $time';
  }

  @override
  String get orderStatusCreated => 'new';

  @override
  String get orderStatusAccepted => 'accepted';

  @override
  String get orderStatusAssembling => 'packing';

  @override
  String get orderStatusDelivering => 'on the way';

  @override
  String get orderStatusDelivered => 'delivered';

  @override
  String get orderStatusCancelled => 'cancelled';

  @override
  String get actionAccept => 'Accept';

  @override
  String get actionReject => 'Decline';

  @override
  String get actionStartAssembly => 'Start packing';

  @override
  String get actionDepart => 'On my way';

  @override
  String get actionDelivered => 'Delivered';

  @override
  String get actionRoute => 'Route';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get rejectConfirmTitle => 'Decline the order?';

  @override
  String get rejectConfirmText =>
      'The order goes back to the dispatcher. This cannot be undone from the app.';

  @override
  String get deliveryTitle => 'Delivery confirmation';

  @override
  String get deliveryHint =>
      'Take a photo of the box at the reception desk — it confirms the delivery.';

  @override
  String get deliveryTakePhoto => 'Photograph the box';

  @override
  String get deliveryRetakePhoto => 'Take another photo';

  @override
  String get deliveryConfirm => 'Confirm delivery';

  @override
  String get deliveryDone => 'Order delivered';

  @override
  String get deliveryPhotoTitle => 'Delivery photo';

  @override
  String get routeTitle => 'Route';

  @override
  String get routeCourier => 'Courier';

  @override
  String get routeOpenInNavigator => 'Open in navigation app';

  @override
  String get routeLaunchFailed => 'Could not open the navigation app';

  @override
  String get logoutButton => 'Sign out';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageEn => 'English';

  @override
  String get languageTr => 'Türkçe';
}

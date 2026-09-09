// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get retry => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get loadingError =>
      'Could not load. Check your connection and try again.';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get catalogTitle => 'Catalogue';

  @override
  String get searchHint => 'Search products';

  @override
  String get categoriesAll => 'All';

  @override
  String get addToCart => 'Add';

  @override
  String get outOfStock => 'Out of stock';

  @override
  String get catalogEmpty => 'Nothing found. Try a different search.';

  @override
  String get popular => 'Popular';

  @override
  String get productToCart => 'Add to cart';

  @override
  String get productInCart => 'In cart';

  @override
  String get productDescriptionTitle => 'Description';

  @override
  String get productSimilar => 'Similar products';

  @override
  String get cartTitle => 'Cart';

  @override
  String get cartEmpty =>
      'Your cart is empty. Browse the catalogue — we deliver to your hotel within an hour.';

  @override
  String get cartTotal => 'Total';

  @override
  String get cartCheckout => 'Check out';

  @override
  String cartMinOrder(String amount) {
    return 'Minimum order is $amount';
  }

  @override
  String get cartClear => 'Clear cart';

  @override
  String cartItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutHotel => 'Hotel';

  @override
  String get checkoutRoom => 'Room number';

  @override
  String get checkoutComment => 'Note for the courier';

  @override
  String get checkoutPromo => 'Promo code';

  @override
  String get checkoutPromoApply => 'Apply';

  @override
  String get checkoutPromoApplied => 'Promo code applied';

  @override
  String get checkoutPromoInvalid => 'Promo code did not work';

  @override
  String get checkoutSubtotal => 'Items';

  @override
  String get checkoutDiscount => 'Discount';

  @override
  String get checkoutDelivery => 'Delivery';

  @override
  String get checkoutTotal => 'To pay';

  @override
  String get checkoutPay => 'Pay';

  @override
  String get checkoutPaymentCard => 'Bank card';

  @override
  String get checkoutPaymentSbp => 'SBP transfer';

  @override
  String get checkoutSuccess => 'Order placed';

  @override
  String get checkoutSuccessSub =>
      'The courier will pack your order and bring it to your hotel reception.';

  @override
  String get checkoutMinOrderError =>
      'Add more items — the minimum order value is not reached';

  @override
  String get ordersTitle => 'My orders';

  @override
  String get ordersEmpty => 'No orders yet. Start with the catalogue.';

  @override
  String orderNumber(int id) {
    return 'Order #$id';
  }

  @override
  String get orderRepeat => 'Repeat order';

  @override
  String get orderDetails => 'Details';

  @override
  String get orderTrack => 'Track';

  @override
  String get orderDeliveryTo => 'Delivering to';

  @override
  String get orderCourier => 'Courier';

  @override
  String get orderPlacedAt => 'Placed';

  @override
  String get orderItems => 'Items';

  @override
  String get orderDeliveryPhoto => 'Delivery photo';

  @override
  String get orderStatusCreated => 'Created';

  @override
  String get orderStatusAccepted => 'Accepted';

  @override
  String get orderStatusAssembling => 'Packing';

  @override
  String get orderStatusDelivering => 'On the way';

  @override
  String get orderStatusDelivered => 'Delivered';

  @override
  String get orderStatusCancelled => 'Cancelled';

  @override
  String get trackingTitle => 'Tracking';

  @override
  String trackingEta(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Courier arrives in $minutes minutes',
      one: 'Courier arrives in $minutes minute',
    );
    return '$_temp0';
  }

  @override
  String get trackingCourierOnWay => 'Courier is on the way';

  @override
  String get trackingArrived => 'Courier has arrived';

  @override
  String get chatTitle => 'Support';

  @override
  String get chatHint => 'Type a message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatBotLabel => 'Bot';

  @override
  String get chatOperatorLabel => 'Operator';

  @override
  String get authTitle => 'Welcome to TUR TUK';

  @override
  String get authSubtitle =>
      'Souvenirs, cosmetics and groceries delivered to your hotel';

  @override
  String get authPhone => 'Phone number';

  @override
  String get authGetCode => 'Get code';

  @override
  String get authCode => 'SMS code';

  @override
  String get authConfirm => 'Confirm';

  @override
  String authResend(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Resend the code in $seconds seconds',
      one: 'Resend the code in $seconds second',
    );
    return '$_temp0';
  }

  @override
  String get authName => 'Name';

  @override
  String get authDob => 'Date of birth';

  @override
  String get authHotel => 'Hotel';

  @override
  String get authRoom => 'Room number';

  @override
  String get authRegisterTitle => 'A little about you';

  @override
  String get authContinue => 'Continue';

  @override
  String get authInvalidCode => 'Wrong code';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileLanguage => 'App language';

  @override
  String get profileRussian => 'Русский';

  @override
  String get profileEnglish => 'English';

  @override
  String get profileTurkish => 'Türkçe';

  @override
  String get profileMyOrders => 'My orders';

  @override
  String get profileSupport => 'Support';

  @override
  String get profileHotel => 'Hotel';

  @override
  String get profileRoom => 'Room number';

  @override
  String get profileLogout => 'Log out';

  @override
  String get profileEdit => 'Edit';
}

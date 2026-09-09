// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get retry => 'Tekrar dene';

  @override
  String get cancel => 'İptal';

  @override
  String get save => 'Kaydet';

  @override
  String get close => 'Kapat';

  @override
  String get loadingError =>
      'Yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get comingSoon => 'Yakında';

  @override
  String get catalogTitle => 'Katalog';

  @override
  String get searchHint => 'Ürün ara';

  @override
  String get categoriesAll => 'Tümü';

  @override
  String get addToCart => 'Sepete ekle';

  @override
  String get outOfStock => 'Stokta yok';

  @override
  String get catalogEmpty => 'Sonuç bulunamadı. Farklı bir arama deneyin.';

  @override
  String get popular => 'Popüler';

  @override
  String get productToCart => 'Sepete ekle';

  @override
  String get productInCart => 'Sepette';

  @override
  String get productDescriptionTitle => 'Açıklama';

  @override
  String get productSimilar => 'Benzer ürünler';

  @override
  String get cartTitle => 'Sepet';

  @override
  String get cartEmpty =>
      'Sepetiniz boş. Kataloğa göz atın — bir saat içinde otelinize getiriyoruz.';

  @override
  String get cartTotal => 'Toplam';

  @override
  String get cartCheckout => 'Siparişi tamamla';

  @override
  String cartMinOrder(String amount) {
    return 'En az sipariş tutarı $amount';
  }

  @override
  String get cartClear => 'Sepeti boşalt';

  @override
  String cartItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ürün',
      one: '$count ürün',
    );
    return '$_temp0';
  }

  @override
  String get checkoutTitle => 'Sipariş';

  @override
  String get checkoutHotel => 'Otel';

  @override
  String get checkoutRoom => 'Oda numarası';

  @override
  String get checkoutComment => 'Kuryeye not';

  @override
  String get checkoutPromo => 'Promosyon kodu';

  @override
  String get checkoutPromoApply => 'Uygula';

  @override
  String get checkoutPromoApplied => 'Promosyon kodu uygulandı';

  @override
  String get checkoutPromoInvalid => 'Promosyon kodu geçersiz';

  @override
  String get checkoutSubtotal => 'Ürünler';

  @override
  String get checkoutDiscount => 'İndirim';

  @override
  String get checkoutDelivery => 'Teslimat';

  @override
  String get checkoutTotal => 'Ödenecek tutar';

  @override
  String get checkoutPay => 'Öde';

  @override
  String get checkoutPaymentCard => 'Banka kartı';

  @override
  String get checkoutPaymentSbp => 'SBP ile havale';

  @override
  String get checkoutSuccess => 'Sipariş alındı';

  @override
  String get checkoutSuccessSub =>
      'Kurye siparişinizi hazırlayıp otelinizin resepsiyonuna getirecek.';

  @override
  String get checkoutMinOrderError =>
      'Biraz daha ürün ekleyin — en az sipariş tutarına ulaşılmadı';

  @override
  String get ordersTitle => 'Siparişlerim';

  @override
  String get ordersEmpty => 'Henüz sipariş yok. Kataloğa göz atarak başlayın.';

  @override
  String orderNumber(int id) {
    return 'Sipariş No $id';
  }

  @override
  String get orderRepeat => 'Siparişi tekrarla';

  @override
  String get orderDetails => 'Ayrıntılar';

  @override
  String get orderTrack => 'Takip et';

  @override
  String get orderDeliveryTo => 'Teslimat adresi';

  @override
  String get orderCourier => 'Kurye';

  @override
  String get orderPlacedAt => 'Oluşturulma';

  @override
  String get orderItems => 'Sipariş içeriği';

  @override
  String get orderDeliveryPhoto => 'Teslimat fotoğrafı';

  @override
  String get orderStatusCreated => 'Oluşturuldu';

  @override
  String get orderStatusAccepted => 'Kabul edildi';

  @override
  String get orderStatusAssembling => 'Hazırlanıyor';

  @override
  String get orderStatusDelivering => 'Yolda';

  @override
  String get orderStatusDelivered => 'Teslim edildi';

  @override
  String get orderStatusCancelled => 'İptal edildi';

  @override
  String get trackingTitle => 'Takip';

  @override
  String trackingEta(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Kurye $minutes dakika içinde geliyor',
      one: 'Kurye $minutes dakika içinde geliyor',
    );
    return '$_temp0';
  }

  @override
  String get trackingCourierOnWay => 'Kurye yolda';

  @override
  String get trackingArrived => 'Kurye geldi';

  @override
  String get chatTitle => 'Destek';

  @override
  String get chatHint => 'Mesaj yazın';

  @override
  String get chatSend => 'Gönder';

  @override
  String get chatBotLabel => 'Bot';

  @override
  String get chatOperatorLabel => 'Operatör';

  @override
  String get authTitle => 'TUR TUK\'a hoş geldiniz';

  @override
  String get authSubtitle =>
      'Hediyelik eşya, kozmetik ve gıdayı otelinize getiriyoruz';

  @override
  String get authPhone => 'Telefon numarası';

  @override
  String get authGetCode => 'Kod gönder';

  @override
  String get authCode => 'SMS kodu';

  @override
  String get authConfirm => 'Onayla';

  @override
  String authResend(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Kodu $seconds saniye sonra tekrar gönder',
      one: 'Kodu $seconds saniye sonra tekrar gönder',
    );
    return '$_temp0';
  }

  @override
  String get authName => 'Ad';

  @override
  String get authDob => 'Doğum tarihi';

  @override
  String get authHotel => 'Otel';

  @override
  String get authRoom => 'Oda numarası';

  @override
  String get authRegisterTitle => 'Sizi biraz tanıyalım';

  @override
  String get authContinue => 'Devam et';

  @override
  String get authInvalidCode => 'Kod hatalı';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileLanguage => 'Uygulama dili';

  @override
  String get profileRussian => 'Русский';

  @override
  String get profileEnglish => 'English';

  @override
  String get profileTurkish => 'Türkçe';

  @override
  String get profileMyOrders => 'Siparişlerim';

  @override
  String get profileSupport => 'Destek';

  @override
  String get profileHotel => 'Otel';

  @override
  String get profileRoom => 'Oda numarası';

  @override
  String get profileLogout => 'Çıkış yap';

  @override
  String get profileEdit => 'Düzenle';
}
